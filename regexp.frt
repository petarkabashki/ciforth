( Copyright{2000}: Albert van der Horst, HCC FIG Holland by GNU Public License)

( $Id$)

: \D ;

'$@ ALIAS @+
REQUIRE TRUE

\ Regular expressions in Forth.
\ This package handles only simple regular expressions and replacements.
\ See the words RE-MATCH and RE-REPLACE for usage.
\ The following aspects are handled:
\    1. Compiling ^ (begin only)  $  (end only) and special characters + ? * [ ] < >
\    2. Grouping using ( ) , only for replacement.
\    3. Above characters must be escaped if used as is.

\ Implementation notes:
\ * Usually regular expressions are compiled into a buffer consisting of
\   tokens followed by strings or characters in some format.
\   We follow the same here, except that tokens are execution tokens.
\ * No attempt is done at reentrant code.
\ * \d \s \w etc. can be handled by making the expression compiler more
\   powerful.

\ Data structures :
\   a char set is a bit set, with a bit up for the matching character.
\   a string is a regular string variable (so with a cell count).

\ Configuration
1000 CONSTANT MAX-RE     \ # cells in a regular expression.
128 8 / CONSTANT MAX-SET \ # chars in a charset. (So no char's > 0x80 !)

\ -----------------------------------------------------------------------
\                      Bit sets
\ -----------------------------------------------------------------------
REQUIRE NEW-DO
\ REQUIRE 2SET+!
: 2SET+! >R SWAP R@ SET+! R> SET+! ;
\ REQUIRE WHERE-IN-SET

( For VALUE and SET return the POSITION of value in set, or a null. )
: WHERE-IN-SET $@ SWAP ?DO
   DUP I @ = IF DROP I UNLOOP EXIT THEN 0 CELL+ +LOOP DROP 0 ;


CREATE BIT-MASK-TABLE 1   8 0 DO DUP C, 1 LSHIFT LOOP DROP
: BIT-MASK   CHARS BIT-MASK-TABLE + C@ ;

\ Set BIT in BITSET
: SET-BIT SWAP 8 /MOD SWAP BIT-MASK >R DUP C@ R> OR SWAP C! ;

\ Clear  BIT in BITSET
: CLEAR-BIT SWAP 8 /MOD SWAP BIT-MASK INVERT >R DUP C@ R> AND SWAP C! ;

\ For BIT in BITSET , return "it IS set".
: BIT? SWAP 8 /MOD SWAP BIT-MASK >R DUP C@ R> AND 0= 0= ;

\ -----------------------------------------------------------------------
\                  char sets, generic part
\ -----------------------------------------------------------------------
: |  OVER SET-BIT ; \ Shorthand, about to be hidden.

\ This contains alternatingly a character, and a pointer to a charset.
\ The charset is denotated by this character preceeded by '\' e.g. \s.
100 SET CHAR-SET-SET     CHAR-SET-SET SET!

\ Allocate a char set and leave a POINTER to it.
: ALLOT-CHAR-SET   HERE 1 C,  MAX-SET 1 - 0 DO 0 C, LOOP
\ Note that ``ASCII'' null must be excluded from every char-set!
\ Algorithms rely on it.
\ For an identifying CHAR create an as yet empty char set with "NAME"
\ and add it to ``CHAR-SET-SET''.
\ Leave a POINTER to the set (to fill it in).
: CHAR-SET CREATE HERE CHAR-SET-SET 2SET+!  ALLOT-CHAR-SET DOES> ;
\ For a CHAR-SET ; convert it into its complementary set.
: INVERT-SET MAX-SET 1+ 0 DO I OVER + DUP C@ INVERT SWAP C! LOOP  0 SWAP CLEAR-BIT ;

\ For CHAR and CHARSET return "it BELONGS to the charset".
: IN-CHAR-SET   BIT? ;

\ ------------------------------------------
\                  char sets, actual part
\ ------------------------------------------

REQUIRE ?BLANK      \ Indicating whether a CHAR is considered blank in this Forth.

&w CHAR-SET \w   256 1 DO I IS-BLANK? 0= IF I | THEN LOOP DROP

\ Example of another set definition
\ &d CHAR-SET \d   &9 1+ &0 DO I | LOOP   DROP
\ &D CHAR-SET \D   \d OVER MAX-SET CMOVE  INVERT-SET

'| HIDDEN

\ -----------------------------------------------------------------------
\                  escape table
\ -----------------------------------------------------------------------
\ To SET add an escape CHAR and the escape CODE. Leave SET .
: | ROT DUP >R 2SET! R> ;    \ Shorthand, about to be hidden.

\ This contains alternatingly an escaped character, and its ASCII meaning.
100 SET ESCAPE-TABLE     ESCAPE-TABLE SET!
&n ^J |   &r ^M |   &b ^H |   &t ^I |   &e ^Z 1+ |   DROP

\ For CHARACTER return the ``ASCII'' VALUE it represents, when escaped.
: GET-ESCAPE ESCAPE-TABLE WHERE-IN-SET DUP IF CELL+ @ _ THEN DROP ;
'| HIDDEN


\ -----------------------------------------------------------------------
\                  substrings
\ -----------------------------------------------------------------------
\ This table contains the ends and starts of matching substrings between ( )
\ 0 is what matches the whole expression, and is available without ( )
CREATE SUBSTRING-TABLE 20 CELLS ALLOT
\ To where has the table been used (during expression parsing).
VARIABLE ALLOCATOR
\ Initialise ALLOCATOR
: ALLOCATOR! 2 ALLOCATOR ! ;
\ Return a new ALLOCATOR index, and increment it.
: ALLOCATOR++
    ALLOCATOR @ DUP 11 = ABORT" Too many substrings with ( ), max 9, user error"
    1 ALLOCATOR +! ;

\ Return a new INDEX for a '('.
: ALLOCATE( ALLOCATOR++
DUP 1 AND ABORT" ( where ) expected, inproper nesting, user error" ;
\ Return a new INDEX for a ')'.
: ALLOCATE( ALLOCATOR++
DUP 1 AND 0= ABORT" ) where ( expected, inproper nesting, user error" ;

\ Remember CHARPOINTER as the substring with INDEX.
: REMEMBER()
\D DUP 0 10 WITHIN 0= ABORT" substring index out of range, system error"
CELLS SUBSTRING-TABLE + ! ;

\ For INDEX create a "word" that returns the matched string with that index.
: CREATE\ 2 * CELLS SUBTRING-TABLE + , DOES> @ 2@ SWAP OVER - ;

0 CREATE\ \0    1 CREATE\ \1    2 CREATE\ \2    3 CREATE\ \3   4 CREATE\ \4
5 CREATE\ \5    6 CREATE\ \6    7 CREATE\ \7    8 CREATE\ \8   9 CREATE\ \9

\ -----------------------------------------------------------------------

\ The compiled pattern.
\ It contains xt's, strings and charsets in a sequential format, i.e.
\ you can only find out what it means by reading from the beginning.
\ It is NULL-ended.
\ BNF = <term>+ <endsentinel>
\ term = <quantifier>? <atom> CHAR-SET | 'ADVANCE-EXACT STRING-VARIABLE
\ atom = 'ADVANCE-CHAR
\ quantifier = 'ADVANCE? | 'ADVANCE+ | 'ADVANCE*
\ endsentinel = 0
\ For nested expressions one could add :
\ atom = 'ADVANCE( <term>+ <endsentinel>

CREATE RE-PATTERN MAX-RE CELLS ALLOT
\ Backup from ADDRESS one cell. Leave decremented ADDRESS.
: CELL- 0 CELL+ - ;
\ For CHARPOINTER and EXPRESSIONPOINTER :
\ bla bla + return "there IS a match"
: (MATCH) BEGIN @+ DUP WHILE EXECUTE 0= IF CELL- FALSE EXIT THEN REPEAT CELL- TRUE;

\ For CHARPOINTER and EXPRESSIONPOINTER :
\ as long as the character agrees with the matcher at the expression,
\ advance it.
\ Return CHARPOINTER advanced and EXPRESSIONPOINTER advanced past the matcher.
    \ From ONE TWO THREE FOUR leave THREE and TWO
    : KEEP32 DROP >R >R DROP R> R> SWAP ;
    \ From ONE TWO THREE FOUR leave ONE and FOUR
    : KEEP14 >R DROP DROP R> ;
: (ADVANCE*)   @+ >R BEGIN 2DUP R@ EXECUTE WHILE KEEP32 REPEAT KEEP14 RDROP ;

\ This would benefit from locals :
\ : (ADVANCE*) @+ LOCAL MATCHER   LOCAL EP   LOCAL CP
\         BEGIN CP EP MATCHER EXECUTE WHILE DROP TO CP REPEAT
\         TO EP DROP     CP EP ;

\ For CHARPOINTER and EXPRESSIONPOINTER and BACKTRACKPOINTER :
\ if there is match between btp and cp with the ep,
\ return CHARPOINTER ann EXPRESSIONPOINTER incremented past the match,
\ else return BTP and EP. Plus "there IS a match".
: BACKTRACK
    >R BEGIN (MATCH) 0= WHILE
        OVER R@ = IF RDROP FALSE EXIT THEN
        \ WARNING: 1 - will go wrong if there is a larger gap between backtrackpoints
        \ i.e. when ADVANCE( is there that would use larger leaps than ADVANCE-CHAR.
        SWAP 1 - SWAP
    REPEAT
    RDROP TRUE ;

\-----------------------------------------------------------------
\           xt's that may be present in a compiled expression
\-----------------------------------------------------------------

\ All of those xt's accept a charpointer and an expressionpointer.
\ The char pointer points into the string to be matched that must be
\ zero ended. The expressionpointer points into the buffer with
\ Polish xt's, i.e. xt's to be executed with a pointer to the
\ data following the xt.
\ They either leave those as is, and return FALSE, or
\ If the \ match still stands after the operation intended,
\ both pointers are bumped passed the characters consumed, and
\ data, and possibly more xt's and more data consumed.
\ The incremented pointers are returned, plus a true flag.
\ Otherwise the pointers are returned unchanged, plus a false flag.
\ The xt's need not do a match, they can do an operation that
\ never fails, such as remembering a pointer.


\ For CHARPOINTER and EXPRESSIONPOINTER :
\ if the character matches the charset at the expression,
\ advance both past the match, else leave them as is.
\ Return CHARPOINTER and EXPRESSIONPOINTER and "there IS a match".
\ In a regular expression buffer this xt must be followed by a char-set.
: ADVANCE-CHAR  OVER C@ OVER IN-SET? DUP >R IF SWAP CHAR+ SWAP MAX-SET CHARS + THEN R> ;

\ For CHARPOINTER and EXPRESSIONPOINTER :
\ if the char sequence at charpointer matches the string variable at the
\ expressionpointer, advance both past the match, else leave them as is.
\ Return CHARPOINTER and EXPRESSIONPOINTER and "there IS a match".
\ In a regular expression buffer this xt must be followed by a string.
: ADVANCE-EXACT  2DUP $@ CORA 0= DUP >R IF $@ >R SWAP R@ + SWAP R> + ALIGNED THEN R> ;

\ For CHARPOINTER and EXPRESSIONPOINTER :
\ if there is match between cp and the end of string with the ep,
\ return CHARPOINTER and EXPRESSIONPOINTER incremented past the match,
\ else return CP and EP. Plus "there IS a match".
\ (Note: this is the syncronisation, to be done when the expression does
\ *not* start with `^'.
: FORTRACK
    BEGIN (MATCH) 0= WHILE
        SWAP 1 + SWAP
        OVER C@ 0= IF FALSE EXIT THEN
    REPEAT
    RDROP TRUE ;

\ For CHARPOINTER and EXPRESSIONPOINTER :
\ return CHARPOINTER and EXPRESSIONPOINTER plus "the strings HAS been used up".
\ (Note: this is an end-check, to be done only when the expression ends with '$'.)
: CHECK$
\D DUP @ 0= ABORT" CHECK$ compiled not at end of expression, system error"
    OVER C@ 0= ;

\ For CHARPOINTER and EXPRESSIONPOINTER :
\ return CHARPOINTER and EXPRESSIONPOINTER plus "we ARE at the start of a word"
: CHECK< OVER STARTPOINTER @ = DUP 0= IF DROP OVER 1- C@ \w IN-CHAR-SET 0= THEN >R
         OVER C@ DUP IF \w IN-CHAR-SET THEN   R> AND ;

\ For CHARPOINTER and EXPRESSIONPOINTER :
\ return CHARPOINTER and EXPRESSIONPOINTER plus "we ARE at the end of a word"
: CHECK< OVER STARTPOINTER @ = 0= DUP IF DROP OVER 1- C@ \w IN-CHAR-SET THEN >R
         OVER C@ DUP IF \w IN-CHAR-SET THEN 0=  R> AND ;

\D DUP @ 0= ABORT" CHECK$ compiled not at end of expression, system error"
    OVER C@ 0= ;

\ For CHARPOINTER and EXPRESSIONPOINTER :
\ Remember this as the start or end of a substring.
\ Leave CHARPOINTER and leave the EXPRESSIONPOINTER after the substring number.
\ Plus "yeah, it IS okay"
\ In case you wonder, because the offset is known, during backtracking just
\ the last (and final) position is remembered.
: HANDLE() @+ >R   OVER R> REMEMBER() TRUE ;

\ If the following match xt (at ``EXPRESSIONPOINTER'' ) works out,
\ with the modifier ( * + ? ) ,
\ advance both past the remainder of the expression, else leave them as is.
\ Return CHARPOINTER and EXPRESSIONPOINTER and "there IS a match".
\ In a regular expression buffer each of those xt must be followed by the
\ xt of ADVANCE-CHAR.
: ADVANCE? OVER >R @+ EXECUTE DROP R> BACKTRACK ;
: ADVANCE* OVER >R   (ADVANCE*) R> BACKTRACK ;
: ADVANCE+ DUP >R @+ EXECUTE IF DROP R> ADVANCE* ELSE RDROP FALSE THEN ;