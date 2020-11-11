# Fredag 23. oktober
Status: Funker mer eller mindre men skjer noe feil på cntr=14
Ifølge Python script skal MM1 returnere 0x78e06c47d97f0ffe597f187a95597b9486a0de268b265cec86651fd490ede8a5
Simulering gir:                           32fc10e9013e5fbc9621349b8b9fa633d697dd7ae99545b87b4c8f1ee46574a9

Så vi har en feil i modular_mult:

A = 00000000901381f94b44b3f96adbe05593e6d1f4322d64484648a00240020001
B = 00000000901381f94b44b3f96adbe05593e6d1f4322d64484648a00240020001
n = d5286d56ea8485df7e3124f15bac98b065fc8e385dfba734382efdf88a28796b

Bør bare være å trace ned hver klokkesyklus for å finne buggen.
Ellers så kan det være en ide å bruke kun 1 modular_mult
Vi får se hva slags frekvens vi klarer å klokke den på.
En ting er sikkert. Vi trenger skikkelig testing. Nå har jeg kun jobbet med et enkelt scenario. Verilator virka egt. ganske gull med Verilog osv. Ifølge ARM er det Verilog som er industri-standarden. Ikke VHDL.


#  Tirsdag 27. Oktober
Status: Tror den vanlige versjonen fungerer. Men ikke Radix-2n versjonen. Tror uansett egentlig at jeg ikke kommer til å få plass til den.

Status er: PROC_MODMULT1 gir 0x606 burde gi 0xf78.

Så må gå inn i MM1 og gå gjennom 


## Wednesday 4 November
It failed on the Pynq, now I am trying to run the testbenches provided but it fucking fails to include modular mult. JESUS CHRIST how fucking stupid are Xilinx, why cant they fix that horrendous software? MY GOD\rant


OK. Ta å cleanup regenrate project mellom hver. GOTTO GO bby


08F9BAF32E8505CBC9A28FED4D5791DCE46508C3D1636232BF91F5D0B6632A9F
08F9BAF32E8505CBC9A28FED4D5791DCE46508C3D1636232BF91F5D0B6632A9F


## Monday 8 November:
Started working on a generic radix-n implementation. Very curios to see how this will proceed. Gonna go for a radix16 now.
Q1: Does my use of for generate work with arrays?
Q2: How do I pick the overflow size correctly. Pleease dont make me look at 32 different subtractions each iteration...

Fuck. What I should do is introduce pipelining.... with C_last, god damn of course.
With the right number of pipeline registers we can do more stuff in parallell.

We have essentially 2 operations:
1. Multiply_add
2. Reduce

Our parameter becomes: 
How many mult+reduce pairs can we add? Makes sense to do pipeline reg in between them.

So we have 1 parameter: stages:

with 1 stage we have 1 mult+reduce and we 
with 2 stages we have 2 mult+reduce and so on
And each CC we move data from 1 PP reg to the next. Also a valid and a last signal needs to be present. 
How could I not see this before?


## Tuesday 9 November:
Started working on the pipelined version. It compiles and simulates but fails the TB test.
Just figure it out with stages=1 then 2 then 4 and so on.