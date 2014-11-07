%{
//predefined keyword
#include "lib/common.h"
#include "lib/symbolTable.h"
#include "lib/hashtb.h"
#define LIST                { strncat(buf, yytext, sizeof(buf) - strlen(buf) - 1); }
#define token(t)            { LIST; if (Opt_Token) printf("<%s>\n", t); }
#define tokenString(t, s)   { LIST; if (Opt_Token) printf("<%s:%s>\n", t, s); }
//initial variables
int Opt_Source = 1;
int Opt_Token = 1;
int Opt_Statistic = 1;
int linenum = 1;
char buf[MAX_LINE_LENGTH];
char stringBuf[MAX_LINE_LENGTH];
struct SymbolTable symbolTable;
struct hashtb* st;
struct hashtb_enumerator* ste;
char* quote (char* target, char* src)
{
  int n = strlen (src), i;
  target[0]   = '\"';
  target[1]   = '\0';
  strncat (target, src, n);
  target[n+1] = '\"';
  target[n+2] = '\0';
  return target;
}
char* unquote (char* target, char* src)
{
  int n = strlen (src) - 2, i;
  strncpy(target, src+1, n);
  return target;
}
void addID (const char* id)
{
    hashtb_seek (ste, (void*) id, strlen(id), 1);
    int * frequency = hashtb_lookup (st, (void*)id, strlen(id));
    (*frequency)++;
}
void endOfLine ()
{
    LIST;
    if (Opt_Source)
        printf("%d:%s\n", linenum, buf);
    ++linenum;
    buf[0] = '\0';
}
void errorLex()
{
    fprintf(stderr, "Error at line %d: %s\n", linenum, yytext);
    exit(1);
}
//\"(\\.|[^\\\n"])*\"                    { tokenString ("string", unquote (stringBuf, yytext)); }
%}
digit     [0-9]
letter    [a-zA-Z]
integer   0|([1-9]{digit}*)
float     {digit}+\.{digit}+
keyword   "while"|"do"|"if"|"else"|"true"|"false"|"for"|"int"|"print"|"const"|"read"|"boolean"|"bool"|"void"|"float"|"double"|"string"|"continue"|"break"|"return"
directive "source"|"statistics"|"token"
%x BCOMMENT LCOMMENT DIRECTIVE DIRECTIVEEND D_STATISTIC D_SOURCE D_TOKEN STRING

%%
<INITIAL,DIRECTIVEEND>"/*" { BEGIN BCOMMENT; LIST; }
<INITIAL,DIRECTIVEEND>"//" { BEGIN LCOMMENT; LIST; }
<BCOMMENT>\n            endOfLine();
<BCOMMENT,LCOMMENT>.    LIST;
<BCOMMENT>"*/"          { BEGIN INITIAL; LIST; }
<LCOMMENT>\n            { BEGIN INITIAL; endOfLine(); }
^"#pragma"[ \t]+             {LIST; BEGIN DIRECTIVE;}
<DIRECTIVE>"source"[ \t]+    {LIST; BEGIN D_SOURCE;}
<DIRECTIVE>"statistic"[ \t]+ {LIST; BEGIN D_STATISTIC;}
<DIRECTIVE>"token"[ \t]+     {LIST; BEGIN D_TOKEN;;}
<D_STATISTIC>"on"[ \t]*     {LIST;  BEGIN DIRECTIVEEND; Opt_Statistic = 1;}
<D_STATISTIC>"off"[ \t]*    {LIST;  BEGIN DIRECTIVEEND; Opt_Statistic = 0;}
<D_SOURCE>"on"[ \t]*        {LIST;  BEGIN DIRECTIVEEND; Opt_Source = 1;}
<D_SOURCE>"off"[ \t]*       {LIST;  BEGIN DIRECTIVEEND; Opt_Source = 0;}
<D_TOKEN>"on"[ \t]*         {LIST;  BEGIN DIRECTIVEEND; Opt_Token = 1;}
<D_TOKEN>"off"[ \t]*        {LIST;  BEGIN DIRECTIVEEND; Opt_Token = 0;}
<DIRECTIVE,D_STATISTIC,D_SOURCE,D_TOKEN>. errorLex ();
<DIRECTIVEEND>\n   { BEGIN INITIAL; endOfLine(); }
<DIRECTIVEEND>[^\n] errorLex ();

[(){},;\[\]]                           { tokenString ("delim", yytext); }
{integer}                              { tokenString ("integer", yytext); }
{float}                                { tokenString ("float", yytext); }
{keyword}                              { tokenString ("KW", yytext); }
({float}|{integer})(e|E)[-+]?{digit}+  { tokenString ("scientific", yytext); }
{letter}+({letter}|{digit})*           { tokenString ("id", yytext); addID(yytext); }
<INITIAL>\"                            { LIST; BEGIN STRING; stringBuf[0] = '\0'; }
<STRING>\n                             { LIST; errorLex (); }
<STRING>\\\"                           { LIST; strcat (stringBuf, "\""); }
<STRING>\\[^"]|[^\\\n"]                { LIST; strcat (stringBuf, yytext); }
<STRING>\"                             { BEGIN INITIAL; tokenString ("string", stringBuf); }

[-+*/%<>!=]|[<>!=]?=|"&&"|"||"         { token (quote (stringBuf,yytext)); }
\n                                     endOfLine();
[\t ]                                  LIST; //ignored charactor
.                                      errorLex ();
%%

int main( int argc, char **argv )
{
    st  = hashtb_create (sizeof(int), NULL);
    ste = calloc (1, sizeof(*ste));
    hashtb_start (st, ste);
    if (argc >= 2)
    {
        yyin = fopen( argv[1], "r" );
        if ( NULL == yyin ) {
            fprintf( stderr, "Cannot open: %s\n", argv[1] );
            exit(-1);
        }
    }
    else
    {
        yyin = stdin;
    }

    yylex();

    if (Opt_Statistic)
    {
        int i;
        hashtb_end (ste);
        hashtb_start (st, ste);
        printf ("frequencies of identifiers:\n");
        while (ste->key != NULL)
          {
             printf ("%s\t%d\n", ste->key, *(int*)(ste->data));
             hashtb_next (ste);
          }
    }

    hashtb_end (ste);
    hashtb_destroy (&st);
    exit(0);
}

