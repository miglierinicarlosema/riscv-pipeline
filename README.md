# Etapa IF – Pipeline RISC-V (TP final)

Primera etapa del pipeline: **PC + memoria de instrucciones + latch IF/ID**, con el puerto de escritura que va a usar la Debug Unit para cargar el programa por UART.

## Archivos

| Archivo | Qué hace |
|---|---|
| `rtl/pc.v` | Program Counter con enable y selección de salto |
| `rtl/instr_mem.v` | Memoria de programa: lectura combinacional + puerto de escritura para la Debug Unit |
| `rtl/if_id.v` | Latch IF/ID (PC, PC+4, instrucción) con enable y flush |
| `rtl/if_stage.v` | Une los tres módulos |
| `tb/tb_if_stage.v` | Testbench autoverificable (32 verificaciones) |

## Puertos de `if_stage` (contrato con la Debug Unit)

| Señal | Dirección | Ancho | Quién la maneja | Qué hace |
|---|---|---|---|---|
| `i_en` | entrada | 1 | Debug Unit | Enable global: 1 = avanza. Paso a paso = 1 durante un ciclo |
| `i_stall` | entrada | 1 | Unidad de riesgos | Congela PC e IF/ID (por ahora en 0) |
| `i_flush` | entrada | 1 | Lógica de saltos | Pone un NOP en IF/ID (por ahora en 0) |
| `i_pc_src`, `i_pc_target` | entrada | 1, 32 | Lógica de saltos | Salto tomado y destino (por ahora en 0) |
| `i_imem_we`, `i_imem_waddr`, `i_imem_wdata` | entrada | 1, 8, 32 | Debug Unit | Escritura de la memoria de programa (índice de palabra) |
| `o_ifid_pc`, `o_ifid_pc_plus4`, `o_ifid_instr` | salida | 32 c/u | → ID y Debug Unit | Contenido del latch IF/ID |
| `o_pc` | salida | 32 | → Debug Unit | PC actual |

## Decisiones de diseño (para el informe)

1. **Nunca se toca el clock.** Todo se congela con `i_en && !i_stall`.
2. **Reset sincrónico, activo en alto**, en todo el diseño.
3. **Memoria con lectura combinacional** (RAM distribuida en la FPGA). La instrucción sale en el mismo ciclo, como en el libro. Con Block RAM habría un ciclo de latencia y habría que rediseñar IF.
4. **256 instrucciones** (1 KB). Se cambia con el parámetro `DEPTH`.
5. **Memoria inicializada con NOP** (`addi x0, x0, 0` = `0x00000013`).
6. **NOP para el flush**, en vez de ceros: `0x00000000` no es una instrucción válida en RISC-V.
7. **HALT = `0xFFFFFFFF`** (se detecta en ID, cuando exista).
8. **El flush solo actúa con `i_en = 1`**: con el procesador detenido no cambia nada.

## Cómo correr la simulación

**En Vivado:** agregar los 4 archivos de `rtl/` como *Design Sources* y `tb/tb_if_stage.v` como *Simulation Source*. Después, *Run Simulation → Run Behavioral Simulation*. En la consola tiene que aparecer `ETAPA IF: TODO OK`.

**Con Icarus Verilog** (más liviano):

```
iverilog -g2012 -o tb_if rtl/*.v tb/tb_if_stage.v
vvp tb_if
gtkwave tb_if_stage.vcd      # para ver las formas de onda
```

## Próximo paso

Etapa **ID**: banco de registros (con `x0` siempre en 0 y un puerto de lectura para la Debug Unit), unidad de control, generador de inmediatos, detección del HALT y latch ID/EX.
