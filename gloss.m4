include(prelude.m4)dnl
include(postlude.m4)dnl 
define({prev},{{MyTop()}})dnl
define({worddoc},{
divert(9)dnl
@node $1, next$2(), prev(), MyTop()
@subsection $1

NAME: $1 

STACKEFFECT: $3

DESCRIPTION: $5

define({prev},{$1})dnl
divert(0)dnl
{{$1})dnl
define({next$2},}
divert(4)dnl
* $1  ::  
divert(9)dnl
})dnl
define({worddocsafe},{
divert(9)dnl
@node $2, next$2(), prev(), MyTop()
@subsection $2

NAME: $1 

STACKEFFECT: $3

DESCRIPTION: $5

define({prev},{$2})dnl
divert(0)dnl
{{$2})dnl
define({next$2},}
divert(4)dnl
* $1  : $2  
divert(9)dnl
})dnl
divert(0)dnl
{define({dummy},}
divert(9)dnl
divert(3)dnl
{)dnl}
divert(4)dnl
@menu
divert(5)dnl
@end menu
divert(8)dnl


