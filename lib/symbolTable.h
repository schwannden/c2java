struct SymbolEntry {
  char key[MAX_ID_LENGTH];
  int frequency;
};
typedef struct SymbolEntry SymbolEntry;

struct SymbolTable {
  SymbolEntry entry[MAX_SYMBOL];
  int numOfSymbol;
};
typedef struct SymbolTable SymbolTable;

int STfind (SymbolTable* table, const char* key);
int STinsert (SymbolTable* table, const char* key);
