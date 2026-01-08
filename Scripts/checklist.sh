#!/bin/bash

# -------------------------------
# Configuración
# -------------------------------
DMENU_OPTS=(-i -l 1000)  # insensible a mayúsculas, hasta 1000 líneas
THEME=(-fn "Fira Code-17" -nb "#1d2021" -nf "#ebdbb2" -sb "#176786" -sf "#ebdbb2")

# -------------------------------
# Función para mostrar proyectos
# -------------------------------
show_main_menu() {
    task _projects | dmenu "${DMENU_OPTS[@]}" "${THEME[@]}"
}

# -------------------------------
# Función para mostrar tareas de un proyecto
# -------------------------------
show_items_menu() {
    local project="$1"
    # Obtener solo descripciones de tareas pendientes
    task project:"$project" +PENDING export 2>/dev/null | jq -r '.[].description' | dmenu "${DMENU_OPTS[@]}" "${THEME[@]}"
}

# -------------------------------
# Procesar tarea: toggle/add
# -------------------------------
process_item() {
    local project="$1"
    local selection="$2"

    [[ -z "$selection" ]] && return

    # Buscar tarea exacta en JSON
    task_id=$(task project:"$project" +PENDING export | \
        jq -r --arg desc "$selection" '.[] | select(.description==$desc) | .id')

    if [[ -n "$task_id" ]]; then
        task "$task_id" done
        echo "Marked done: $selection"
    else
        task add project:"$project" "$selection"
        echo "Added new task: $selection"
    fi
}

# -------------------------------
# Crear proyecto si no existe
# -------------------------------
create_project_if_missing() {
    local project="$1"
    if ! task _projects | grep -qx "$project"; then
        # Crear placeholder temporal
        task add project:"$project" "__placeholder__"
        id=$(task project:"$project" +PENDING limit:1 _ids)
        # Borrar automáticamente sin confirmación
        task rc.confirmation=no "$id" delete
        echo "Project created: $project"
    fi
}

# -------------------------------
# Eliminar proyecto completo
# -------------------------------
delete_project() {
    local project="$1"

    # Borrar todas las tareas pendientes sin confirmación
    for id in $(task project:"$project" +PENDING _ids); do
        task rc.confirmation=no "$id" delete
    done

    # Borrar todas las tareas completadas también
    for id in $(task project:"$project" +COMPLETED _ids); do
        task rc.confirmation=no "$id" delete
    done

    echo "Deleted project: $project"
}

# -------------------------------
# Renombrar proyecto
# -------------------------------
rename_project() {
    local old="$1"
    local new="$2"

    # Crear proyecto nuevo si no existe
    create_project_if_missing "$new"

    # Mover todas las tareas pendientes
    for id in $(task project:"$old" +PENDING _ids); do
        task $id modify project:"$new"
    done

    # Mover tareas completadas también (opcional)
    for id in $(task project:"$old" +COMPLETED _ids); do
        task $id modify project:"$new"
    done

    echo "Renamed project: $old → $new"
}

# -------------------------------
# Renombrar tarea
# -------------------------------
rename_task() {
    local project="$1"
    local old_desc="$2"
    local new_desc="$3"

    id=$(task project:"$project" +PENDING export | \
        jq -r --arg desc "$old_desc" '.[] | select(.description==$desc) | .id')

    if [[ -n "$id" ]]; then
        task "$id" modify description:"$new_desc"
        echo "Renamed task: $old_desc → $new_desc"
    fi
}

# -------------------------------
# Función principal
# -------------------------------
main() {
    while true; do
        # Menú de proyectos
        project=$(show_main_menu)
        [[ -z "$project" ]] && break

        # Detectar comandos especiales tipo --remove, --rename
        if [[ "$project" == *" --remove" ]]; then
            local proj="${project% --remove}"
            delete_project "$proj"
            continue
        elif [[ "$project" == *" --rename "* ]]; then
            local old="${project%% --rename *}"
            local new="${project#* --rename }"
            rename_project "$old" "$new"
            continue
        fi

        # Crear proyecto si no existía
        create_project_if_missing "$project"

        # Menú de tareas
        while true; do
            selection=$(show_items_menu "$project")
            [[ -z "$selection" ]] && break

            # Detectar renombrado de tarea: "viejo --rename nuevo"
            if [[ "$selection" == *" --rename "* ]]; then
                old="${selection%% --rename *}"
                new="${selection#* --rename }"
                rename_task "$project" "$old" "$new"
                continue
            fi

            process_item "$project" "$selection"
        done
    done
}

main
