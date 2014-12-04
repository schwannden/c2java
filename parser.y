%{
#include "stdio.h"
#include "stdlib.h"
#include "lib/common.h"
#include "lib/symbolTable.h"
#include "lib/hashtb.h"
#include "y.tab.h"

extern struct SymbolTable symbolTable;
extern struct hashtb* st;
extern struct hashtb_enumerator* ste;
extern int linenum;             /* declared in lex.l */
extern FILE *yyin;              /* declared by lex */
extern char *yytext;            /* declared by lex */
extern char buf[256];           /* declared in lex.l */
int yyerror( char *msg );
int yylex( );
void reductionLog(const char* msg) { fprintf(stderr,"%s\n", msg); }
%}

%union {
  int value;
  int op_int;
  char op_char;
  char delim_type;
}

%token <value>  ID LITERAL_INT LITERAL_FLOAT LITERAL_STRING
%token <delim_type> ',' ';' '(' ')' '[' ']' '{' '}'
%token <value>  WHILE DO IF ELSE TRUE FALSE FOR INT PRINT CONST READ BOOL VOID FLOAT DOUBLE STRING CONTINUE BREAK RETURN
%left <op_char> OR
%left <op_char> AND
%left <op_char> '!'
%left <op_char> '<' '>'
%left <op_int>  LTE GTE NEQ EQ
%left <op_char> '+' '-'
%left <op_char> '*' '/' '%'

%start program
%%
program : decl_and_def_list {reductionLog("program->decl_def_listn");}
        ;

identifier : ID
     ;  

type : INT
     | DOUBLE
     | FLOAT
     | STRING
     | BOOL
     ; 

literal_num : LITERAL_INT
            | LITERAL_FLOAT
            ;

literal_constant : literal_num
                 | LITERAL_STRING
                 | TRUE
                 | FALSE
                 ;

decl_and_def_list  : declaration decl_and_def_list {reductionLog("decl_def_list->decl decl_def_list");}
                   | definition decl_and_def_list  {reductionLog("decl_def_list->def decl_def_list");}
                   | definition                    {reductionLog("decl_def_list->def");}
                   ;

declaration : const_decl    {reductionLog("decl->const_decl");}
            | variable_decl {reductionLog("decl->variable_decl");}
            | function_decl {reductionLog("decl->function_decl");}
            ;

const_decl : CONST type const_list ';' {reductionLog("const_decl-> const type const_list");}
           ;

const_list : identifier '=' literal_constant ',' const_list
           | identifier '=' literal_constant
           ;

variable_decl : type id_list ';' {reductionLog("var_decl->type id_list;");}
         | type identifier brackets_const ';'
         ;

id_list : identifier ',' id_list
        | identifier
        ;

brackets_const : '[' LITERAL_INT ']' brackets_const
         | '[' LITERAL_INT ']'
         ;

function_decl : type ID '(' formal_lists ')' ';'
              | VOID ID '(' formal_lists ')' ';'
              ;

formal_lists : type identifier ',' formal_lists  {reductionLog("formal_list -> type id, ");}
             | type identifier brackets_const ',' formal_lists
             | type identifier      {reductionLog("formal_list -> type id, ");}
             | type identifier brackets_const
             |                      {reductionLog("formal_list ->  ");}
             ;

definition : function_def {reductionLog("def -> func_def");}
           | variable_def
           ;

function_def : type ID '(' formal_lists ')' compound_statement {reductionLog("func_def -> type ID (formal_list) compound_stat");}
             | VOID ID '(' formal_lists ')' compound_statement {reductionLog("func_def -> VOID ID (formal_list) compound_stat");}
             ;

variable_def : type variable_list ';'
             | type identifier brackets_const '=' '{' expression_list '}' ';'
             ;

variable_list : identifier '=' expression ',' variable_list
              | identifier '=' expression
              ;

expression_list : expression ',' expression_list
                | expression
                |
                ;

statement : compound_statement
          | simple_statement
          | conditional_stat
          | while_stat
          | for_stat
          | jump_stat
          | functional_stat
          ;

compound_statement : '{' compound_body '}' {reductionLog("comp_stat -> { comp_body }");}
                   ;

compound_body : const_decl compound_body
              | variable_decl compound_body
              | statement compound_body
              | const_decl
              | variable_decl
              | statement {reductionLog("comp_stat -> { comp_body }");} 
              |
              ;

simple_statement : assignment_stat
                 | variable_def
                 | PRINT expression ';'
                 | READ variable_reference ';'
                 | PRINT variable_reference ';' 
                 ;


assignment_stat :  assignment_expr ';' {reductionLog ("assignment_stat -> assignment_expr;");} 
                ;

assignment_expr : variable_reference '=' expression {reductionLog ("assignment_expr->var_ref = expr");}
                ;

variable_reference : identifier brackets_expr
                   | identifier
                   ;

brackets_expr : '[' expression ']' brackets_expr
         | '[' expression ']'
         ;

expression : literal_constant
           | variable_reference
           | relational_expr  {reductionLog ("exp->relational_expr");}
           | arithmetic_expr  {reductionLog ("exp->arithmetic_expr");}
           | functional_expr  {reductionLog ("exp->functional_expr");}
           | expression AND expression  {reductionLog ("expression->expr AND expr");}
           | expression OR  expression  {reductionLog ("expression->expr OR expr");}
           | '!' expression
           | '(' expression ')'
           ;

relational_expr : expression '>' expression {reductionLog ("relational_expr->expr > expr");}
                | expression '<' expression {reductionLog ("relational_expr->expr < expr");}
                | expression LTE expression {reductionLog ("relational_expr->expr <= expr");}
                | expression GTE expression {reductionLog ("relational_expr->expr >= expr");}
                | expression NEQ expression {reductionLog ("relational_expr->expr != expr");}
                | expression EQ  expression {reductionLog ("relational_expr->expr == expr");}
                ;

arithmetic_expr : expression '+' expression {reductionLog ("arithmetic_expr->expr + expr");}
                | expression '-' expression {reductionLog ("arithmetic_expr->expr - expr");}
                | expression '*' expression {reductionLog ("arithmetic_expr->expr * expr");}
                | expression '/' expression {reductionLog ("arithmetic_expr->expr / expr");}
                | expression '%' expression {reductionLog ("arithmetic_expr->expr %% expr");}
                | '-' expression %prec '+'  {reductionLog ("arithmetic_expr->-expr");}
                ;

functional_expr : identifier '(' expression_list ')'
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
          | BREAK ';'
          | CONTINUE ';'
          ;

%%

int yyerror( char *msg )
{
  fprintf( stderr, "\n|--------------------------------------------------------------------------\n" );
  fprintf( stderr, "| Error found in Line #%d: %s\n", linenum, buf );
  fprintf( stderr, "|\n" );
  fprintf( stderr, "| Unmatched token: %s\n", yytext );
  fprintf( stderr, "|--------------------------------------------------------------------------\n" );
  exit(-1);
}

int  main( int argc, char **argv )
{
  if( argc != 2 ) {
    fprintf(  stdout,  "Usage:  ./parser  [filename]\n"  );
    exit(0);
  }

  st  = hashtb_create (sizeof(int), NULL);
  ste = calloc (1, sizeof(*ste));
  hashtb_start (st, ste);

  FILE *fp = fopen( argv[1], "r" );
  
  if( fp == NULL )  {
    fprintf( stdout, "Open  file  error\n" );
    exit(-1);
  }
  
  yyin = fp;
  yyparse();

  fprintf( stdout, "\n" );
  fprintf( stdout, "|--------------------------------|\n" );
  fprintf( stdout, "|  There is no syntactic error!  |\n" );
  fprintf( stdout, "|--------------------------------|\n" );

  hashtb_end (ste);
  hashtb_destroy (&st);
  exit(0);
}

