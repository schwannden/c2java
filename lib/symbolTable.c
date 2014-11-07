#include "common.h"
#include "symbolTable.h"
int STinsert (SymbolTable* table, const char* key)
{
  if (table->numOfSymbol == MAX_SYMBOL) 
  {
    fprintf (stderr, "Error: SymbolTable.insert(%s): MAX_SYMBOL reached\n", key);
    return -1;
  }
  else
  {
    strncpy(table->entry[table->numOfSymbol].key, key,
            sizeof (table->entry[table->numOfSymbol].key));
    table->entry[table->numOfSymbol].frequency = 1;
    table->numOfSymbol++;
    return 0;
  }
}

int STfind (SymbolTable* table, const char* key)
{
  int i;
  for (i = 0 ; i < table->numOfSymbol ; i++) {
    if (strncmp (table->entry[i].key, key, sizeof (table->entry[0].key)) == 0) return i;
  }
  return -1;
}
