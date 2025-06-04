#!/bin/bash

# Função para mostrar o menu principal
menu_principal() {
    clear
    echo "---------------> Relatório sobre utilizadores <---------------"
    echo "| 1 -----> Espaço em Disco Utilizado por Utilizador           |      "
    echo "| 2 -----> Listagem de Utilizadores por Espaço Ocupado        |"
    echo "| 3 -----> Listagem de Ficheiros por Tipo para um Utilizador  |"
    echo "| 0 -----> Sair                                               |"
    echo "|_____________________________________________________________|"
    echo ""
    read -p "Escolha uma opção: " opcao
}

# Função para espaço utilizado por utilizador
espaco_por_utilizador() {
    clear
    echo "------------------------------------"
    echo "  Espaço por utilizador             "
    echo "____________________________________"
    echo ""
    read -p "Introduza o username ou padrão a pesquisar (ex: user*, *ana): " padrao
    
    # Verificar se o padrão contém caracteres especiais
    if [[ $padrao == *"*"* ]]; then
        # Encontrar utilizadores que correspondem ao padrão
        users=$(getent passwd | cut -d: -f1 | grep -E "${padrao//\*/.*}")
    else
        # Verificar se o utilizador existe
        if id "$padrao" &>/dev/null; then
            users=$padrao
        else
            echo "Utilizador '$padrao' não encontrado."
            echo ""
            read -p "Pressione Enter para continuar."
            return
        fi
    fi
    
    if [ -z "$users" ]; then
        echo "Nenhum utilizador encontrado com o padrão '$padrao'."
        echo ""
        read -p "Pressione Enter para continuar."
        return
    fi
    
    read -p "Introduza o diretório base para pesquisa (ex: /home): " dir_base
    if [ ! -d "$dir_base" ]; then
        echo "Diretório '$dir_base' não existe."
        echo ""
        read -p "Pressione Enter para continuar."
        return
    fi
    
    echo ""
    echo "Relatório para o(s) utilizador(es): $(echo $users | tr '\n' ' ')"
    echo "Diretório base: $dir_base"
    echo "------------------------------------"
    echo "Utilizador        Espaço    Ficheiros"
    echo "____________________________________"
    echo ""
    
    total_space=0
    total_files=0
    
    for user in $users; do
        # Encontrar ficheiros do utilizador e calcular espaço
        user_files=$(find "$dir_base" -type f -user "$user" 2>/dev/null)
        user_dirs=$(find "$dir_base" -type d -user "$user" 2>/dev/null)
        
        space=0
        file_count=0
        
        # Calcular espaço para ficheiros
        if [ -n "$user_files" ]; then
            space=$(du -sc $(echo "$user_files" | tr '\n' ' ') 2>/dev/null | tail -1 | cut -f1)
            file_count=$(echo "$user_files" | wc -l)
        fi
        
        # Adicionar espaço para diretórios (apenas o próprio, não o conteúdo)
        if [ -n "$user_dirs" ]; then
            dir_space=$(du -sc --apparent-size $(echo "$user_dirs" | tr '\n' ' ') 2>/dev/null | tail -1 | cut -f1)
            space=$((space + dir_space))
        fi
        
        printf "%-16s %6d MB %8d\n" "$user" "$((space/1024))" "$file_count"
        
        total_space=$((total_space + space))
        total_files=$((total_files + file_count))
    done
    
    echo "------------------------------------"
    printf "%-16s %6d MB %8d\n" "TOTAL" "$((total_space/1024))" "$total_files"
    echo "____________________________________"
    echo ""
    read -p "Pressione Enter para continuar."
    echo ""
}

# Função para listar utilizadores por espaço ocupado
listar_por_espaco() {
    clear
    echo "------------------------------------"
    echo "  Utilizadores por espaço ocupado   "
    echo "____________________________________"
    echo ""
    read -p "Introduza o diretório base para pesquisa (ex: /home): " dir_base
    if [ ! -d "$dir_base" ]; then
        echo "Diretório '$dir_base' não existe."
        read -p "Pressione Enter para continuar."
        return
    fi
    
    read -p "Ordenar por ordem crescente ou decrescente? (c/d): " ordem
    
    echo ""
    echo "Relatório de utilizadores por espaço ocupado"
    echo "Diretório base: $dir_base"
    echo ""
    echo "------------------------------------"
    echo ""
    echo "Utilizador        Espaço"
    echo ""
    echo "____________________________________"
    echo ""
    
    # Obter lista de todos os utilizadores com ficheiros no diretório
    users=$(find "$dir_base" -type f -printf "%u\n" 2>/dev/null | sort | uniq)
    
    declare -A user_space
    
    # Calcular espaço para cada utilizador
    for user in $users; do
        space=$(find "$dir_base" -type f -user "$user" -exec du -cb {} + 2>/dev/null | tail -1 | cut -f1)
        user_space["$user"]=$space
    done
    
    # Ordenar por espaço
    if [ "$ordem" = "c" ]; then
        sorted_users=$(for user in "${!user_space[@]}"; do
            echo "${user_space[$user]} $user"
        done | sort -n | awk '{print $2 " " $1}')
    else
        sorted_users=$(for user in "${!user_space[@]}"; do
            echo "${user_space[$user]} $user"
        done | sort -nr | awk '{print $2 " " $1}')
    fi
    
    # Mostrar resultados
    total_space=0
    while read -r user space; do
        printf "%-16s %6d MB\n" "$user" "$((space/1024))"
        total_space=$((total_space + space))
    done <<< "$sorted_users"
    
    echo "------------------------------------"
    printf "%-16s %6d MB\n" "TOTAL" "$((total_space/1024))"
    echo "____________________________________"
    echo ""
    read -p "Pressione Enter para continuar."
}

# Função para listar ficheiros por tipo para um utilizador
listar_ficheiros_por_tipo() {
    clear
    echo "____________________________________"
    echo ""
    echo "  Ficheiros por tipo por utilizador"
    echo ""
    echo "____________________________________"
    echo ""
    read -p "Introduza o username: " user
    
    if ! id "$user" &>/dev/null; then
        echo "Utilizador '$user' não encontrado."
        echo ""
        read -p "Pressione Enter para continuar."
        return
    fi
    
    read -p "Introduza o diretório base para pesquisa (ex: /home): " dir_base
    if [ ! -d "$dir_base" ]; then
        echo "Diretório '$dir_base' não existe."
        echo ""
        read -p "Pressione Enter para continuar."
        return
    fi
    
    echo ""
    echo "-----> Tipos de ficheiros disponíveis: <-----"
    echo "| 1 -----> Por extensão (ex: .txt, .pdf)     |"
    echo "| 2 -----> Ficheiros executáveis             |"
    echo "| 3 -----> Diretórios                        |"
    echo "| 4 -----> Ficheiros regulares               |"
    echo "|____________________________________________|"
    echo ""
    read -p "Escolha o tipo de ficheiro: " tipo_op
    
    case $tipo_op in
        1)
            read -p "Introduza a extensão (ex: txt, pdf): " extensao
            padrao="*.${extensao//./}"
            find_cmd="-type f -name '$padrao'"
            descricao="Ficheiros com extensão .$extensao"
            ;;
        2)
            find_cmd="-type f -executable"
            descricao="Ficheiros executáveis"
            ;;
        3)
            find_cmd="-type d"
            descricao="Diretórios"
            ;;
        4)
            find_cmd="-type f"
            descricao="Ficheiros regulares"
            ;;
        *)
            echo "Opção inválida."
            echo ""
            echo "Pressione Enter para continuar."
            read            
            ;;
    esac
    
    echo ""
    echo "Relatório de $descricao para o utilizador: $user"
    echo "Diretório base: $dir_base"
    echo "________________________________"
    
    # Executar o comando find
    eval "find \"$dir_base\" $find_cmd -user \"$user\" -ls 2>/dev/null" | awk '{print $11, $7, $5}' | column -t
    
    # Contar o número de ficheiros
    count=$(eval "find \"$dir_base\" $find_cmd -user \"$user\" 2>/dev/null" | wc -l)
    echo "------------------------------------"
    echo ""
    echo "Total de $descricao: $count"
    echo ""
    echo "____________________________________"
    echo ""
    read -p "Pressione Enter para continuar."
}

# Loop principal do menu
while true; do
    menu_principal
    case $opcao in
        1) espaco_por_utilizador ;;
        2) listar_por_espaco ;;
        3) listar_ficheiros_por_tipo ;;
        0) echo "A sair. :)"; exit 0 ;;
        *)
            echo "Opção inválida. Prima Enter para tentar novamente"
            read
            ;;

    esac
done
