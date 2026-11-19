# =============================================================================
# create_project.tcl - Crea el proyecto de Vivado a partir del repositorio
# -----------------------------------------------------------------------------
# El proyecto de Vivado NO se versiona: cada uno lo genera con este script.
# Agrega automáticamente TODOS los archivos de:
#   rtl/*.v            -> fuentes de diseño
#   tb/*.v             -> fuentes de simulación
#   constraints/*.xdc  -> constraints (pines de la Arty Z7-10)
#   ip/*.xci           -> IP de Vivado (Clock Wizard, etc.), si hay
# Los archivos NO se copian: el proyecto usa directamente los del repositorio,
# así que lo que edites en Vivado queda en el repo.
#
# Cómo usarlo (desde la raíz del repositorio):
#   - En Vivado: Tools -> Run Tcl Script... -> elegir create_project.tcl
#   - O en la consola Tcl de Vivado:  source <ruta al repo>/create_project.tcl
#   - O desde una terminal:           vivado -mode batch -source create_project.tcl
#
# Cuando alguien agrega archivos nuevos: git pull y volver a correr el script
# (recrea el proyecto con todos los archivos; no se pierde código porque los
# archivos viven en el repositorio, no en el proyecto).
# =============================================================================

set proj_name "riscv_pipeline"
set part      "xc7z010clg400-1"         ;# Arty Z7-10

# Carpeta del repositorio = donde está este script
set root     [file normalize [file dirname [info script]]]
set proj_dir "$root/vivado/$proj_name"

# Si el proyecto está abierto, cerrarlo antes de recrearlo
catch {close_project}

create_project $proj_name $proj_dir -part $part -force
set_property target_language Verilog [current_project]

# Agrega los archivos que coincidan con un patrón, si hay alguno
proc add_if_any {fileset pattern} {
    set files [glob -nocomplain $pattern]
    if {[llength $files] > 0} {
        add_files -norecurse -fileset $fileset $files
        puts "  $fileset: [llength $files] archivo(s) de $pattern"
    } else {
        puts "  $fileset: no hay archivos en $pattern"
    }
}

puts "Agregando archivos desde $root"
add_if_any sources_1 "$root/rtl/*.v"
add_if_any sim_1     "$root/tb/*.v"
add_if_any constrs_1 "$root/constraints/*.xdc"
add_if_any sources_1 "$root/ip/*/*.xci"

# Módulos principales. Cambiarlos cuando exista el procesador completo:
#   diseño     -> el top del sistema (UART + Debug Unit + pipeline)
#   simulación -> el testbench que quieran correr por defecto
set_property top if_stage    [get_filesets sources_1]
set_property top tb_if_stage [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Proyecto creado en $proj_dir"
