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