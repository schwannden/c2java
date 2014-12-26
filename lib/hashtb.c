/**
 * @file hashtb.c
 * @brief Hash table.
 * 
 * Part of the NDNx C Library.
 *
 * Portions Copyright (C) 2013 Regents of the University of California.
 * 
 * Based on the CCNx C Library by PARC.
 * Copyright (C) 2009 Palo Alto Research Center, Inc.
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License version 2.1
 * as published by the Free Software Foundation.
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details. You should have received
 * a copy of the GNU Lesser General Public License along with this library;
 * if not, write to the Free Software Foundation, Inc., 51 Franklin Street,
 * Fifth Floor, Boston, MA 02110-1301 USA.
 */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "hashtb.h"

size_t
hashtb_hash(const unsigned char *key, size_t key_size)
{
    size_t h;
    size_t i;
    for (h = key_size + 23, i = 0; i < key_size; i++)
        h = ((h << 6) ^ (h >> 27)) + key[i];
    return(h);
}

Hashtb *
hashtb_create(size_t item_size, const Hashtb_param *param)
{
    Hashtb *ht;
    ht = (Hashtb*) calloc(1, sizeof(*ht));
    if (ht != NULL) {
        ht->item_size = item_size;
        ht->n = 0;
        ht->n_buckets = 7;
        ht->bucket = (Node**) calloc(ht->n_buckets, sizeof(ht->bucket[0]));
	if (ht->bucket == NULL) {
		free(ht);
		return (NULL); /*ENOMEM*/
	}
        if (param != NULL)
            ht->param = *param;
    }
    return(ht);
}

void *
hashtb_get_param(Hashtb *ht, Hashtb_param *param)
{
    if (param != NULL)
        *param = ht->param;
    return(ht->param.finalize_data);
}

//why use hashtb ** instead of hashtb *
void
hashtb_destroy(Hashtb **htp)
{
    if (*htp != NULL) {
        Hashtb_enumerator tmp;
        Hashtb_enumerator *e = hashtb_start(*htp, &tmp);
        while (e->key != NULL)
            hashtb_delete(e);
        hashtb_end(&tmp);
        if ((*htp)->refcount == 0) {
            free((*htp)->bucket);
            free(*htp);
            *htp = NULL;
        }
        else
            abort(); /* perhaps a bit brutal... */
    }
}

int
hashtb_n(Hashtb *ht)
{
    return(ht->n);
}

void *
hashtb_lookup(Hashtb *ht, const void *key, size_t keysize)
{
    Node *p;
    size_t h;
    if (key == NULL)
        return(NULL);
    h = hashtb_hash( (const unsigned char*) key, keysize);
    for (p = ht->bucket[h % ht->n_buckets]; p != NULL; p = p->link) {
        if (p->hash < h)
            continue;
        if (p->hash > h)
            break;
        if (keysize == p->keysize && 0 == memcmp(key, KEY(ht, p), keysize))
            return(DATA(ht, p));
    }
    return(NULL);
}

//set hashtb_enumerator to point to pp (a pointer to a particular bucket)
static void
setpos(Hashtb_enumerator *hte, Node **pp)
{
    Hashtb *ht = hte->ht;
    Node *p = NULL;
    hte->priv[0] = pp;
    if (pp != NULL)
        p = *pp;
    if (p == NULL) {
        hte->key = NULL;
        hte->keysize = 0;
        hte->extsize = 0;
        hte->data = NULL;
    }
    else {
        hte->key = KEY(ht, p);
        hte->keysize = p->keysize;
        hte->extsize = p->extsize;
        hte->data = DATA(ht, p);
    }
}

//return first non-null bucket after bucket b
static Node **
scan_buckets(Hashtb *ht, unsigned b)
{
    for (; b < ht->n_buckets; b++)
        if (ht->bucket[b] != NULL)
            return &(ht->bucket[b]);
    return(NULL);
}

#define MAX_ENUMERATORS 30
Hashtb_enumerator *
hashtb_start(Hashtb *ht, Hashtb_enumerator *hte)
{
    MARKHTE(ht, hte);
    hte->datasize = ht->item_size;
    hte->ht = ht;
    ht->refcount++;
    if (ht->refcount > MAX_ENUMERATORS)
        abort(); /* probably somebody is missing a call to hashtb_end() */
    setpos(hte, scan_buckets(ht, 0));
    return(hte);
}

void
hashtb_end(Hashtb_enumerator *hte)
{
    Hashtb *ht = hte->ht;
    Node *p;
    hashtb_finalize_proc f;
    if (!CHECKHTE(ht, hte) || ht->refcount <= 0) abort();
    if (ht->refcount == 1) {
        /* do deferred deallocation */
        f = ht->param.finalize;
        while (ht->deferred != NULL) {
            setpos(hte, &(ht->deferred));
            if (f != NULL)
                (*f)(hte);
            p = ht->deferred;
            ht->deferred = p->link;
            free(p);
        }
    }
    hte->priv[0] = 0;
    hte->priv[1] = 0;
    ht->refcount--;
}

int
hashtb_next(Hashtb_enumerator *hte)
{
    Node **pp = (Node**) hte->priv[0];
    Node **ppp;
    if (pp != NULL) {
        ppp = pp;
        pp = &((*pp)->link);
        if (*pp == NULL)
           pp = scan_buckets(hte->ht, ((*ppp)->hash % hte->ht->n_buckets) + 1);
    }
    setpos(hte, pp);
    if (hte->key == NULL) return 0;
    else return 1;
}

int
hashtb_seek(Hashtb_enumerator *hte, const void *key, size_t keysize, size_t extsize)
{
    Node *p = NULL;
    Hashtb *ht = hte->ht;
    Node **pp;
    size_t h;
    if (key == NULL) {
        setpos(hte, NULL);
        return(-1);
    }
    if (ht->refcount == 1 && ht->n > ht->n_buckets * 3) {
        ht->refcount--;
        hashtb_rehash(ht, 2 * ht->n + 1);
        ht->refcount++;
    }
    h = hashtb_hash((const unsigned char*) key, keysize);
    pp = &(ht->bucket[h % ht->n_buckets]);
    for (p = *pp; p != NULL; pp = &(p->link), p = p->link) {
        if (p->hash < h)
            continue;
        if (p->hash > h)
            break;
        if (keysize == p->keysize && 0 == memcmp(key, KEY(ht, p), keysize)) {
            setpos(hte, pp);
            return(HT_OLD_ENTRY);
        }
    }
    p = (Node*) calloc(1, sizeof(*p) + ht->item_size + keysize + extsize);
    if (p == NULL) {
        setpos(hte, NULL);
        return(-1);
    }
    memcpy(KEY(ht, p), key, keysize + extsize);
    p->hash = h;
    p->keysize = keysize;
    p->extsize = extsize;
    p->link = *pp;
    *pp = p;
    hte->ht->n += 1;
    setpos(hte, pp);
    return(HT_NEW_ENTRY);
}

void
hashtb_delete(Hashtb_enumerator *hte)
{
    Hashtb *ht = hte->ht;
    Node **pp = (Node**) hte->priv[0];
    Node *p = *pp;
    if ((p != NULL) && CHECKHTE(ht, hte) && KEY(ht, p) == hte->key) {
        *pp = p->link;
        if (*pp == NULL)
           pp = scan_buckets(hte->ht, (p->hash % hte->ht->n_buckets) + 1);
        hte->ht->n -= 1;
        if (ht->refcount == 1) {
            hashtb_finalize_proc f = ht->param.finalize;
            if (f != NULL)
                (*f)(hte);
            free(p);
        }
        else {
            p->link = ht->deferred;
            ht->deferred = p;
        }
        setpos(hte, pp);
    }
}

void
hashtb_rehash(Hashtb *ht, unsigned n_buckets)
{
    Node **bucket = NULL;
    Node **pp;
    Node *p;
    Node *q;
    size_t h;
    unsigned i;
    unsigned b;
    if (ht->refcount != 0 || n_buckets < 1 || n_buckets == ht->n_buckets)
        return;
    bucket = (Node**) calloc(n_buckets, sizeof(bucket[0]));
    if (bucket == NULL) return; /* ENOMEM */
    for (i = 0; i < ht->n_buckets; i++) {
        for (p = ht->bucket[i]; p != NULL; p = q) {
            q = p->link;
            h = p->hash;
            b = h % n_buckets;
            for (pp = &bucket[b]; *pp != NULL && ((*pp)->hash < h); pp = &((*pp)->link))
                continue;
            p->link = *pp;
            *pp = p;
        }
    }
    free(ht->bucket);
    ht->bucket = bucket;
    ht->n_buckets = n_buckets;
}

void
stack_init (Stack* stack, size_t item_size)
{
    stack->top = 0;
    stack->front = -1;
    stack->item_size = item_size;
}

int
push (Stack* stack)
{
    stack->front++;
    stack->top++;
    stack->tables[stack->front].item_size = stack->item_size;
    stack->tables[stack->front].n = 0;
    stack->tables[stack->front].n_buckets = 7;
    stack->tables[stack->front].bucket = (Node**) calloc(stack->tables[stack->front].n_buckets, sizeof(stack->tables[0].bucket[0]));
    if (stack->tables[stack->front].bucket == NULL) {
        return (-1); /*ENOMEM*/
    }
    return stack->front;
}

void
pop (Stack* stack)
{
    Hashtb* p = &(stack->tables[stack->front]);
    Hashtb_enumerator ste;
    Hashtb_enumerator *e = hashtb_start(p, &ste);
    while (e->key != NULL)
        hashtb_delete(e);
    hashtb_end(&ste);
    if (p->refcount == 0)
        free(p->bucket);
    stack->top--;
    stack->front--;
}
