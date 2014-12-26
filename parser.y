%{
#include "stdio.h"
#include "stdlib.h"
#include "lib/common.h"
#include "lib/hashtb.h"
#include "y.tab.h"

Hashtb_enumerator* ste;
extern int linenum;             /* declared in lex.l */
extern FILE *yyin;              /* declared by lex */
extern char *yytext;            /* declared by lex */
extern char buf[256];           /* declared in lex.l */
char buf2[32];           /* declared in lex.l */
Attributes* attribute;
char idStack[MAX_STACK_SIZE][MAX_ID_LENGTH];
int is_top = 0, i;
int dimensionStack[MAX_DIMENSION];
int ds_top = 0;
int formalStack[MAX_FORMAL_SIZE][MAX_DIMENSION];
int fs_top = 0;
struct exp actualStack[MAX_FORMAL_SIZE];
int as_top = 0;
int scope = 0;
int returnType;

int yyerror( char *msg );
int yylex( );
void reductionLog(const char* msg) { fprintf(stderr,"%s\n", msg); }
Attributes* addID (const char* id);
void printID (Hashtb_enumerator* ste);
int semanticError (const char *fmt, ...);
void funcDeclCheck (Hashtb_enumerator* ste, int ret);
void checkDefined (const char* id);
int checkOpType (int op, struct exp x, struct exp y);
int canConvert (int t1, int t2);
int canConvertR (int t1, int t2);
int isNumber (int a);
const char* kind (Attributes* attribute);
void printTable ();
const char* val2type (int val);

%}

%union {
  int value;
  char op_char;
  char delim_type;
  char id[MAX_ID_LENGTH+1];
  struct exp exp;
}

%token <value> ID LITERAL_INT LITERAL_FLOAT LITERAL_STRING
%token <value> ',' ';' '(' ')' '[' ']' '{' '}'
%token <value>  WHILE DO IF ELSE TRUE FALSE FOR INT PRINT CONST READ BOOL VOID FLOAT DOUBLE STRING CONTINUE BREAK RETURN
%left OR
%left AND
%left '!'
%left '<' '>'
%left LTE GTE NEQ EQ
%left '+' '-'
%left '*' '/' '%'

%type <exp> expression variable_reference
%type <value> type literal_num literal_constant relational_expr arithmetic_expr
%type <value> functional_expr brackets_const brackets_expr
%type <id> identifier

%start program
%%
program : decl_and_def_list
        ;

identifier : ID { strcpy($$, yylval.id); }
           ;

type : INT    {$$ = INT   ;}
     | DOUBLE {$$ = DOUBLE;}
     | FLOAT  {$$ = FLOAT ;}
     | STRING {$$ = STRING;}
     | BOOL   {$$ = BOOL  ;}
     ; 

literal_num : LITERAL_INT   {$$ = LITERAL_INT  ;}
            | LITERAL_FLOAT {$$ = LITERAL_FLOAT;}
            ;

literal_constant : literal_num    {$$ = $1            ;}
                 | LITERAL_STRING {$$ = LITERAL_STRING;}
                 | TRUE           {$$ = TRUE          ;}
                 | FALSE          {$$ = FALSE         ;}
                 ;

decl_and_def_list  : declaration decl_and_def_list
                   | definition decl_and_def_list 
                   | definition                   
                   ;

declaration : const_decl
            | function_decl
            | variable_decl
            ;

const_decl : CONST type const_list ';'
           ;

const_list : identifier '=' literal_constant ',' const_list
           | identifier '=' literal_constant
           ;

variable_decl : type id_list ';'
                {
                  for (i = 0 ; i < is_top ; i++)
                    {
                      Attributes* attribute = addID (idStack[i]);
                      if ( attribute->defined ) semanticError ("%s is defined", idStack[i]);
                      attribute->type = $1;
                      attribute->defined = 1;
                      attribute->declared = 1;
                      attribute->scope = scope;
                    }
                  is_top = 0;
                }
              | type identifier brackets_const ';'
                {
                  Attributes* attribute = addID ($2);
                  if ( attribute->defined ) semanticError ("%s is defined", idStack[i]);
                  attribute->type = $1;
                  attribute->defined = 1;
                  attribute->declared = 1;
                  attribute->scope = scope;
                  for (i = 0 ; i < ds_top ; i++)
                    {
                      attribute->array[i] = dimensionStack[i];
                    }
                  ds_top = 0;
                }
              ;

id_list : identifier ','
          {
            strcpy (idStack[is_top++] , $1);
          }
          id_list
        | identifier
          {
            strcpy (idStack[is_top++] , $1);
          }
        ;

brackets_const : '[' LITERAL_INT ']'
                 {
                   dimensionStack[ds_top++] = $2;
                 }
                 brackets_const
               | '[' LITERAL_INT ']'
                 {
                   dimensionStack[ds_top++] = $2;
                   dimensionStack[ds_top] = 0;
                 }
               ;

function_decl : type identifier '(' formal ')' ';'
                {
                  Attributes* attribute = addID ($2);
                  if ( attribute->declared ) semanticError ("%s has been declared");
                  if ( attribute->defined )  semanticError ("%s has been defined");
                  attribute->type = $1;
                  attribute->declared = 1;
                  attribute->scope = scope;
                  for (i = 0 ; i < fs_top ; i++)
                    {
                      int t = 0;
                      for (t = 0 ; formalStack[i][t] != 0 ; t++)
                        attribute->function[i][t] = formalStack[i][t];
                      attribute->function[i][t] = 0;
                    }
                  if (fs_top == 0)
                    attribute->function[0][0] = VOID;
                  is_top = 0;
                  fs_top = 0;
                  ds_top = 0;
                }
              | VOID identifier '(' formal ')' ';'
                {
                  Attributes* attribute = addID ($2);
                  if ( attribute->declared ) semanticError ("%s has been declared");
                  if ( attribute->defined )  semanticError ("%s has been defined");
                  attribute->type = VOID;
                  attribute->declared = 1;
                  attribute->scope = scope;
                  for (i = 0 ; i < fs_top ; i++)
                    {
                      int t = 0;
                      for (t = 0 ; formalStack[i][t] != 0 ; t++)
                        attribute->function[i][t] = formalStack[i][t];
                      attribute->function[i][t] = 0;
                    }
                  if (fs_top == 0)
                    attribute->function[0][0] = VOID;
                  is_top = 0;
                  fs_top = 0;
                  ds_top = 0;
                }
              ;

formal : formal_list
       | VOID
       |
       ;

formal_list : type identifier ','
              {
                strcpy (idStack[is_top++] , $2);
                formalStack[fs_top][0] = $1;
                formalStack[fs_top][1] = 0;
                fs_top++;
              }
              formal_list
            | type identifier brackets_const ','
              {
                strcpy (idStack[is_top++] , $2);
                formalStack[fs_top][0] = $1;
                for (i = 0 ; i < ds_top ; i++)
                  {
                    formalStack[fs_top][i+1] = dimensionStack[i];
                  }
                formalStack[fs_top][ds_top+1] = 0;
                ds_top = 0;
                fs_top++;
              }
              formal_list
            | type identifier
              {
                strcpy (idStack[is_top++] , $2);
                formalStack[fs_top][0] = $1;
                formalStack[fs_top][1] = 0;
                fs_top++;
              }
            | type identifier brackets_const
              {
                strcpy (idStack[is_top++] , $2);
                formalStack[fs_top][0] = $1;
                for (i = 0 ; i < ds_top ; i++)
                  {
                    formalStack[fs_top][i+1] = dimensionStack[i];
                  }
                formalStack[fs_top][ds_top+1] = 0;
                ds_top = 0;
                fs_top++;
              }
            ;

definition : function_def
           | variable_def
           ;

function_def : type identifier '(' formal ')' compound_statement
               {
                  Attributes* attribute = addID ($2);
                  if ( attribute->defined ) semanticError ("%s is defined", $2);
                  if ( attribute->declared )
                    {
                      funcDeclCheck (ste, $1);
                      attribute->defined = 1;
                    }
                  else
                    {
                      attribute->type = $1;
                      attribute->declared = 1;
                      attribute->defined = 1;
                      attribute->scope = scope;
                      for (i = 0 ; i < fs_top ; i++)
                        {
                        int t;
                          for (t = 0 ; formalStack[i][t] != 0 ; t++)
                            attribute->function[i][t] = formalStack[i][t];
                          attribute->function[i][t] = 0;
                        }
                      if (fs_top == 0)
                        attribute->function[0][0] = VOID;
                    }
                  if ( attribute->type != VOID && canConvertR (attribute->type, returnType) == 0)
                    semanticError ("function %s return type (%s) different then function signature (%s)",
                                   $2, val2type (returnType), val2type (attribute->type));
                  returnType = 0;
                  is_top = 0;
                  fs_top = 0;
                  ds_top = 0;
                }
             | VOID identifier '(' formal ')' compound_statement
                {
                  Attributes* attribute = addID ($2);
                  if ( attribute->defined ) semanticError ("%s is defined", $2);
                  if ( attribute->declared )
                    {
                      funcDeclCheck (ste, VOID);
                      attribute->defined = 1;
                    }
                  else
                    {
                      attribute->type = VOID;
                      attribute->declared = 1;
                      attribute->defined = 1;
                      attribute->scope = scope;
                      for (i = 0 ; i < fs_top ; i++)
                        {
                        int t;
                          for (t = 0 ; formalStack[i][t] != 0 ; t++)
                            attribute->function[i][t] = formalStack[i][t];
                          attribute->function[i][t] = 0;
                        }
                      if (fs_top == 0)
                        attribute->function[0][0] = VOID;
                    }
                  if ( returnType != 0)
                    semanticError ("function %s return type (%s) different then function signature (%s)",
                                   $2, val2type (returnType), val2type (attribute->type));
                  returnType = 0;
                  is_top = 0;
                  fs_top = 0;
                  ds_top = 0;
                }
             ;

variable_def : type variable_list ';'
               {
                 for (i = 0 ; i < is_top ; i++)
                   {
                     Attributes* attribute = addID (idStack[i]);
                     if ( attribute->defined ) semanticError ("%s is defined", idStack[i]);
                     attribute->type = $1;
                     attribute->defined = 1;
                     attribute->declared = 1;
                     attribute->scope = scope;
                   }
                 is_top = 0;
               }
             | type identifier brackets_const '=' '{' expression_list '}' ';'
               {
                 Attributes* attribute = addID ($2);
                 if ( attribute->defined ) semanticError ("%s is defined", idStack[i]);
                 attribute->type = $1;
                 attribute->defined = 1;
                 attribute->declared = 1;
                 attribute->scope = scope;
                 for (i = 0 ; i < ds_top ; i++)
                   {
                     ((Attributes*)(ste->data))->array[i] = dimensionStack[i];
                   }
                 ds_top = 0;
               }
             ;

variable_list : identifier '=' expression ','
                {
                  strcpy (idStack[is_top++] , $1);
                }
              variable_list 
              | identifier '=' expression
                {
                  strcpy (idStack[is_top++] , $1);
                }
              ;

expression_list : expression ','
                  {
                    actualStack[as_top++] = $1;
                  }
                  expression_list
                | expression
                  {
                    actualStack[as_top++] = $1;
                  }
                ;

statement : compound_statement
          | simple_statement
          | conditional_stat
          | while_stat
          | for_stat
          | jump_stat
          | functional_stat
          ;

compound_statement : '{'
                     {
                       scope++;
                       hashtb_end (ste); push (&stack); hashtb_start (stack.tables+stack.front, ste);
                       for (i = 0 ; i < is_top ; i++)
                         {
                           Attributes* attribute = addID (idStack[i]);
                           attribute->type = formalStack[i][0];
                           attribute->defined = 1;
                           attribute->declared = 1;
                           attribute->scope = scope;
                           if (formalStack[i][1] != 0)
                             {
                               int t;
                               for (t = 1 ; formalStack[i][t] != 0 ; t++)
                                 attribute->array[t-1] = formalStack[i][t];
                             }
                         }
                       printTable ();
                     }
                       compound_body
                     '}'
                     {
                       scope--;
                       printTable ();
                       hashtb_end (ste); pop (&stack);  hashtb_start (stack.tables+stack.front, ste);
                     }
                   ;

compound_body : const_decl compound_body
              | variable_decl compound_body
              | statement compound_body
              | const_decl
              | variable_decl
              | statement
              |
              ;

simple_statement : assignment_stat
                 | variable_def
                 | PRINT expression ';'
                 | READ variable_reference ';'
                 | PRINT variable_reference ';' 
                 ;

assignment_stat :  assignment_expr ';'
                ;

assignment_expr : variable_reference '=' expression
                  {
                    checkOpType ('=', $1, $3);
                  }
                ;

variable_reference : identifier brackets_expr
                     {
                       checkDefined ($1);
                       int t;
                       for (t = 0 ; attribute->array[t] != 0 ; t++) ;
                       $$.type = attribute->type;
                       $$.dimension = t-$2;
                     }
                   | identifier
                     {
                       checkDefined ($1);
                       $$.type = attribute->type;
                       $$.dimension = 0;
                     }
                   ;

brackets_expr : '[' expression ']' brackets_expr
                {
                  if (($2.type != LITERAL_INT && $2.type != INT) || $2.dimension != 0)
                    semanticError ("expression in array reference must be integral type");
                  $$ = $4 + 1;
                }
              | '[' expression ']'
                {
                  if (($2.type != LITERAL_INT && $2.type != INT) || $2.dimension != 0)
                    semanticError ("expression in array reference must be integral type");
                  $$ = 1;
                }
              ;

expression : literal_constant
             {
               if ($1 == TRUE || $1 == FALSE) $$.type = BOOL;
               else $$.type = $1;
               $$.dimension = 0;
             }
           | variable_reference
             {
               $$.type = $1.type;
               $$.dimension = $1.dimension;
             }
           | relational_expr
             {
               $$.type = $1;
               $$.dimension = 0;
             }
           | arithmetic_expr
             {
               $$.type = $1;
               $$.dimension = 0;
             }
           | functional_expr
             {
               $$.type = $1;
               $$.dimension = 0;
             }
           | expression AND expression
             {
               $$.type = BOOL;
               $$.dimension = 0;
             }
           | expression OR  expression
             {
               $$.type = BOOL;
               $$.dimension = 0;
             }
           | '!' expression
             {
               $$.type = BOOL;
               $$.dimension = 0;
             }
           | '(' expression ')'
             {
               $$.type = $2.type;
               $$.dimension = $2.dimension;
             }
           ;

relational_expr : expression '>' expression
                  {
                    checkOpType ('>', $1, $3);
                    $$ = BOOL;
                  }
                | expression '<' expression
                  {
                    checkOpType ('<', $1, $3);
                    $$ = BOOL;
                  }
                | expression LTE expression
                  {
                    checkOpType ('<', $1, $3);
                    $$ = BOOL;
                  }
                | expression GTE expression
                  {
                    checkOpType ('<', $1, $3);
                    $$ = BOOL;
                  }
                | expression NEQ expression
                  {
                    $$ = BOOL;
                  }
                | expression EQ  expression
                  {
                    $$ = BOOL;
                  }
                ;

arithmetic_expr : expression '+' expression
                  {
                    $$ = checkOpType ('+', $1, $3);
                  }
                | expression '-' expression
                  {
                    $$ = checkOpType ('-', $1, $3);
                  }
                | expression '*' expression
                  {
                    $$ = checkOpType ('*', $1, $3);
                  }
                | expression '/' expression
                  {
                    $$ = checkOpType ('/', $1, $3);
                  }
                | expression '%' expression
                  {
                    $$ = checkOpType ('%', $1, $3);
                  }
                | '-' expression %prec '+' 
                  {
                    $$ = checkOpType ('-', $2, $2);
                  }
                ;

functional_expr : identifier '(' actual ')'
                  {
                    checkDefined ($1);
                    if (as_top == 0 && attribute->function[0][0] != VOID)
                      semanticError ("number of actual arg of %s differ from its signature", $1);
                    if (as_top != 0 && (attribute->function[as_top][0] != 0 || attribute->function[as_top-1][0] == 0))
                      semanticError ("number of actual arg of %s differ from its signature", $1);
                    for (i = 0 ; i < as_top ; i++) {
                      if (actualStack[i].type != attribute->function[i][0])
                        semanticError ("%dth argument for %s (%s:%d)differs from its signature",
                                      i, val2type (actualStack[i].type), actualStack[i].dimension, $1);
                      int d = actualStack[i].dimension;
                      if ( d != 0 && (attribute->function[i][d+1] != 0 || attribute->function[i][d] == 0))
                        semanticError ("%dth argument for %s differs from its signature", i, $1);
                    }
                    $$ = attribute->type;
                    as_top = 0;
                  }
                ;

actual : expression_list
       |
       ;

functional_stat : functional_expr ';'
                ;

conditional_stat : IF '(' expression ')' compound_statement ELSE compound_statement
                 | IF '(' expression ')' compound_statement
                 ;

while_stat : WHILE '(' expression ')' compound_statement
           | DO compound_statement WHILE '(' expression ')' ';'
           ;

for_stat : FOR '(' initial_expr ';' expression ';' increment_expr ')' compound_statement
         ;

initial_expr : assignment_expr ',' initial_expr
             | functional_expr ',' initial_expr
             | assignment_expr
             | functional_expr
             |
             ;

increment_expr : initial_expr
               ;

jump_stat : RETURN expression ';'
            {
              if ($2.dimension != 0)
                semanticError ("array can not be returned");
              returnType = $2.type;
            }
          | BREAK ';'
          | CONTINUE ';'
          ;

%%

int yyerror (char *msg)
{
  fprintf( stderr, "\n|--------------------------------------------------------------------------\n" );
  fprintf( stderr, "| Error found in Line #%d: %s\n", linenum, buf );
  fprintf( stderr, "|\n" );
  fprintf( stderr, "| Unmatched token: %s\n", yytext );
  fprintf( stderr, "|--------------------------------------------------------------------------\n" );
  exit(-1);
}

int semanticError (const char *fmt, ...)
{
  va_list ap; 
  va_start (ap, fmt);
#ifdef    HAVE_VSNPRINTF
  vsnprintf(buf, MAXLINE, fmt, ap);
#else
  vsprintf(buf, fmt, ap);
#endif
  fprintf( stderr, "\n##########  Error at #%d: %s  ##########\n", linenum, buf );
  va_end (ap);
  exit(-1);
}

int  main( int argc, char **argv )
{
  if( argc != 2 ) {
    fprintf(  stdout,  "Usage:  ./parser  [filename]\n"  );
    exit(0);
  }

  stack_init( &stack, sizeof(Attributes) );
  push( &stack );
  ste = (Hashtb_enumerator*) calloc (1, sizeof(*ste));
  hashtb_start (stack.tables+stack.front, ste);

  FILE *fp = fopen( argv[1], "r" );
  
  if( fp == NULL )  {
    fprintf( stdout, "Open  file  error\n" );
    exit(-1);
  }
  
  yyin = fp;
  yyparse();

  printTable ();
  fprintf( stdout, "\n" );
  fprintf( stdout, "|--------------------------------|\n" );
  fprintf( stdout, "|  There is no syntactic error!  |\n" );
  fprintf( stdout, "|--------------------------------|\n" );

  hashtb_end (ste);
  pop( &stack );
  exit(0);
}

const char* val2type (int val)
{
  switch (val)
    {
      case INT:    return "int";
      case FLOAT:  return "float";
      case DOUBLE: return "double";
      case STRING: return "string";
      case BOOL:   return "bool";
      case VOID:   return "void";
      default:
        snprintf (buf2, 32, "unknown type(%d)", val);
        return buf2;
    }
}


void printID (Hashtb_enumerator* ste)
{
  Attributes* attribute = (Attributes*)ste->data;
  printf ("%-33s%-11s%-8d", ste->key, kind(attribute), attribute->scope);
  if (attribute->array[0] != 0)
    {
      printf("%s", val2type (attribute->type));
      for (i = 0 ; attribute->array[i] != 0 ; i++)
        {
          printf ("[%d]", attribute->array[i]);
        }
    }
  else if (attribute->function[0][0] != 0)
    {
      printf ("%-10s", val2type (attribute->type));
      for (i = 0 ; attribute->function[i][0] != 0 && attribute->function[i][0] != VOID ; i++)
        {
          if (attribute->function[i][1])
            {
              int t = 0;
              printf ("%s ",val2type ( attribute->function[i][0]));
              for (t = 1 ; attribute->function[i][t] != 0 ; t++)
                printf ("[%d]", attribute->function[i][t]);
            }
          else
            {
              printf ("%s",val2type (attribute->function[i][0]));
            }
          printf (", ");
        }
      if ( i != 0 )
        printf ("\b\b ");
    }
  else
    printf("%s", val2type (attribute->type));
  printf ("\n");
}

Attributes* addID (const char* id)
{
    hashtb_seek (ste, (void*) id, strlen(id), 1);
    ((Attributes*)(ste->data))->frequency++;
    return (Attributes*)(ste->data);
}

void funcDeclCheck (Hashtb_enumerator* ste, int ret)
{
  Attributes* attribute = (Attributes*)(ste->data);
  if (attribute->type != ret) semanticError ("%s is declared with different return type", ste->key);
  for (i = 0 ; i < fs_top ; i++)
    {
      int t;
      for (t = 0 ; formalStack[i][t] != 0 || attribute->function[i][t] != 0; t++)
        if (attribute->function[i][t] != formalStack[i][t])
          semanticError ("%s is declared with different formal argument", ste->key);
    }
}

void checkDefined (const char* id)
{
  for (i = stack.front ; i >= 0 ; i--)
    {
      attribute = hashtb_lookup (stack.tables + i, id, strlen(id));
      if(attribute != NULL)
        {
        if(attribute->defined == 0 ) semanticError ("%s is not yet defined", id);
          else return;
        }
    }
  semanticError ("%s is not yet defined", id);
}

int checkOpType (int op, struct exp x, struct exp y)
{
  if (x.dimension != 0 || y.dimension != 0)
    semanticError ("%c can not operate on array", op);
  int a = x.type, b = y.type;
  switch (op)
    {
      int t;
      case '+': case '-': case '*': case '/':
        if ( isNumber (a) > 0 && isNumber (b) > 0 )
          {
            t = canConvert (a, b);
            if (t > 0) return t;
            else return canConvert (b, a);
          }
        else
          semanticError ("wrong operand of type %s %c %s", val2type (a), op, val2type(b));
      case '%':
        if (a == INT && b == INT) return INT;
        else semanticError ("wrong operand of type %s %c %s", val2type (a), op, val2type(b));
      case '=':
        if (a == LITERAL_INT || a == LITERAL_FLOAT || a == LITERAL_STRING)
          semanticError ("rvalue can not be assigned: %s %c %s", val2type (a), op, val2type(b));
        else if (canConvert (a, b)) return canConvert (a, b);
        else
          semanticError ("Type conversion do not exist: %s %c %s", val2type (a), op, val2type(b));
      case '<': case '>': case LTE: case GTE:
        if ( isNumber (a) > 0 && isNumber (b) > 0 )
          return BOOL;
        else
          semanticError ("wrong operand of type %s %c %s", val2type (a), op, val2type(b));
      default:
        semanticError ("unknown operand %c", op);
        return -1;
    }
}

int canConvert (int t1, int t2)
{
  switch (t1)
    {
      case LITERAL_INT:
        if (t2 == LITERAL_INT || t2 == INT) return LITERAL_INT;
      case INT: 
        if (t2 == INT) return INT;
        else return 0;
      case LITERAL_FLOAT:
        if (t2 == LITERAL_FLOAT || t2 == LITERAL_INT || t2 == INT || t2 == FLOAT) return LITERAL_FLOAT;
      case FLOAT:
        if (t2 == INT || t2 == FLOAT) return FLOAT;
        else return 0;
      case DOUBLE:
        if (t2 == INT || t2 == FLOAT || t2 == DOUBLE) return DOUBLE;
        else return 0;
      case LITERAL_STRING:
        if (t2 == LITERAL_STRING || t2 == STRING) return LITERAL_STRING;
      case STRING:
        if (t2 == STRING) return STRING;
        else return 0;
      case BOOL:
        if (t2 == BOOL) return BOOL;
        else return 0;
      default:
        semanticError ("unknown type of: %s in type conversion", val2type (t1));
        return -1;
    }
}

int canConvertR (int t1, int t2)
{
  switch (t1)
    {
      case LITERAL_INT: case INT: 
        if (t2 == LITERAL_INT || t2 == INT) return LITERAL_INT;
        else return 0;
      case LITERAL_FLOAT: case FLOAT:
        if (t2 == LITERAL_FLOAT || t2 == LITERAL_INT || t2 == INT || t2 == FLOAT) return LITERAL_FLOAT;
        else return 0;
      case DOUBLE:
        if (t2 == INT || t2 == FLOAT || t2 == DOUBLE || t2 == LITERAL_INT || t2 == LITERAL_FLOAT) return DOUBLE;
        else return 0;
      case LITERAL_STRING:
        if (t2 == LITERAL_STRING || t2 == STRING) return LITERAL_STRING;
      case STRING:
        if (t2 == STRING) return STRING;
        else return 0;
      case BOOL:
        if (t2 == BOOL) return BOOL;
        else return 0;
      default:
        semanticError ("unknown type of: %s in type conversion", val2type (t1));
        return -1;
    }
}
int isNumber (int a)
{
  if (a == INT || a == FLOAT || a == DOUBLE || a == LITERAL_INT || a == LITERAL_FLOAT)
    return a;
  else
    return 0;
}

void printTable ()
{
  hashtb_end (ste); hashtb_start (stack.tables+stack.front, ste);
  if (ste->key == NULL) return;
  printf ("===================================================================================================\n");
  printf ("%-33s%-11s%-8s%-10s%-24s\n", "Name", "Kind", "Level", "Type", "Attribute");
  while ( ste->key != NULL ) {
    printID (ste);
    hashtb_next (ste);
  }
  printf ("===================================================================================================\n");
}

const char* kind (Attributes* attribute)
{
  int t = attribute->type;
  if (attribute->function[0][0] != 0)
    return "function";
  else if ( t == LITERAL_INT || t == LITERAL_FLOAT || t == LITERAL_STRING)
    return "constant";
  else
    return "variable";
}
