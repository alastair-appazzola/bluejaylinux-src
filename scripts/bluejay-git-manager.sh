#!/bin/bash

# BluejayLinux - Git GUI & Version Control Manager
# Professional Git interface with comprehensive workflow management

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/bluejay"
GIT_CONFIG_DIR="$CONFIG_DIR/git"
REPOS_DIR="$GIT_CONFIG_DIR/repositories"
CREDENTIALS_DIR="$GIT_CONFIG_DIR/credentials"

# Color scheme
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# Git workflow types
WORKFLOW_TYPES="gitflow feature-branch trunk-based forking-workflow"
MERGE_STRATEGIES="merge rebase squash fast-forward"

# Initialize directories
create_directories() {
    mkdir -p "$CONFIG_DIR" "$GIT_CONFIG_DIR" "$REPOS_DIR" "$CREDENTIALS_DIR"
    chmod 700 "$CREDENTIALS_DIR"
    
    # Create default Git configuration
    if [ ! -f "$GIT_CONFIG_DIR/settings.conf" ]; then
        cat > "$GIT_CONFIG_DIR/settings.conf" << 'EOF'
# BluejayLinux Git Manager Settings
DEFAULT_EDITOR=nano
DEFAULT_MERGE_TOOL=vimdiff
AUTO_FETCH_ENABLED=true
FETCH_INTERVAL=300
SHOW_BRANCH_STATUS=true
AUTO_STAGE_TRACKED=false
COMMIT_SIGNING=false
GPG_KEY_ID=""
DEFAULT_WORKFLOW=feature-branch
PUSH_DEFAULT=simple
PULL_REBASE=false
AUTO_CLEANUP=true
BACKUP_BEFORE_REBASE=true
SHOW_DIFF_IN_COMMIT=true
COLOR_UI=auto
CREDENTIAL_HELPER=store
HTTPS_VERIFICATION=true
SSH_KEY_TYPE=ed25519
HOOKS_ENABLED=true
EOF
    fi
    
    # Initialize repositories database
    touch "$REPOS_DIR/repositories.db"
}

# Load settings
load_settings() {
    if [ -f "$GIT_CONFIG_DIR/settings.conf" ]; then
        source "$GIT_CONFIG_DIR/settings.conf"
    fi
}

# Check Git installation and version
check_git_installation() {
    echo -e "${BLUE}Checking Git installation...${NC}"
    
    if ! command -v git >/dev/null; then
        echo -e "${RED}✗${NC} Git not installed"
        echo -e "${YELLOW}Install with: sudo apt install git${NC}"
        return 1
    fi
    
    local git_version=$(git --version 2>/dev/null)
    echo -e "${GREEN}✓${NC} $git_version"
    
    # Check Git configuration
    local user_name=$(git config --global user.name 2>/dev/null)
    local user_email=$(git config --global user.email 2>/dev/null)
    
    if [ -z "$user_name" ] || [ -z "$user_email" ]; then
        echo -e "${YELLOW}!${NC} Git user configuration missing"
        setup_git_user
    else
        echo -e "${GREEN}✓${NC} User: $user_name <$user_email>"
    fi
    
    return 0
}

# Setup Git user configuration
setup_git_user() {
    echo -e "${BLUE}Setting up Git user configuration...${NC}"
    
    echo -ne "${CYAN}Enter your name:${NC} "
    read -r git_name
    echo -ne "${CYAN}Enter your email:${NC} "
    read -r git_email
    
    if [ -n "$git_name" ] && [ -n "$git_email" ]; then
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        echo -e "${GREEN}✓${NC} Git user configuration saved"
    else
        echo -e "${RED}✗${NC} Invalid user information"
    fi
}

# Clone repository
clone_repository() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="$3"
    
    if [ -z "$repo_url" ]; then
        echo -e "${RED}✗${NC} Repository URL required"
        return 1
    fi
    
    echo -e "${BLUE}Cloning repository...${NC}"
    echo -e "${CYAN}URL: $repo_url${NC}"
    
    # Extract repository name from URL if target_dir not specified
    if [ -z "$target_dir" ]; then
        target_dir=$(basename "$repo_url" .git)
    fi
    
    echo -e "${CYAN}Target: $target_dir${NC}"
    
    # Clone command
    local clone_cmd="git clone"
    if [ -n "$branch" ]; then
        clone_cmd="$clone_cmd --branch $branch"
    fi
    clone_cmd="$clone_cmd $repo_url $target_dir"
    
    if eval "$clone_cmd"; then
        echo -e "${GREEN}✓${NC} Repository cloned successfully"
        
        # Save repository info
        local repo_info="$target_dir|$repo_url|$(date +%s)|cloned"
        echo "$repo_info" >> "$REPOS_DIR/repositories.db"
        
        # Change to repository directory
        cd "$target_dir" || return 1
        
        # Show repository status
        show_repository_status
        
        return 0
    else
        echo -e "${RED}✗${NC} Failed to clone repository"
        return 1
    fi
}

# Initialize new repository
init_repository() {
    local repo_path="${1:-.}"
    local bare="${2:-false}"
    
    echo -e "${BLUE}Initializing Git repository...${NC}"
    echo -e "${CYAN}Path: $repo_path${NC}"
    
    # Create directory if it doesn't exist
    if [ "$repo_path" != "." ] && [ ! -d "$repo_path" ]; then
        mkdir -p "$repo_path"
    fi
    
    cd "$repo_path" || return 1
    
    # Initialize repository
    local init_cmd="git init"
    if [ "$bare" = "true" ]; then
        init_cmd="$init_cmd --bare"
    fi
    
    if eval "$init_cmd"; then
        echo -e "${GREEN}✓${NC} Repository initialized"
        
        # Create initial commit if not bare
        if [ "$bare" = "false" ]; then
            # Create initial files
            echo "# $(basename "$(pwd)")" > README.md
            echo "node_modules/" > .gitignore
            echo ".env" >> .gitignore
            echo "*.log" >> .gitignore
            
            git add README.md .gitignore
            git commit -m "Initial commit"
            echo -e "${GREEN}✓${NC} Initial commit created"
        fi
        
        # Save repository info
        local repo_info="$(pwd)|local|$(date +%s)|initialized"
        echo "$repo_info" >> "$REPOS_DIR/repositories.db"
        
        return 0
    else
        echo -e "${RED}✗${NC} Failed to initialize repository"
        return 1
    fi
}

# Show repository status
show_repository_status() {
    if [ ! -d ".git" ]; then
        echo -e "${RED}✗${NC} Not a Git repository"
        return 1
    fi
    
    echo -e "\n${PURPLE}=== Repository Status ===${NC}"
    
    # Current branch and upstream
    local current_branch=$(git branch --show-current 2>/dev/null)
    local upstream=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)
    
    echo -e "${CYAN}Repository:${NC} $(basename "$(pwd)")"
    echo -e "${CYAN}Branch:${NC} $current_branch"
    if [ -n "$upstream" ]; then
        echo -e "${CYAN}Upstream:${NC} $upstream"
        
        # Show commits ahead/behind
        local ahead=$(git rev-list --count @{upstream}..HEAD 2>/dev/null)
        local behind=$(git rev-list --count HEAD..@{upstream} 2>/dev/null)
        
        if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
            echo -e "${CYAN}Sync:${NC} ${ahead} ahead, ${behind} behind"
        else
            echo -e "${GREEN}Sync: Up to date${NC}"
        fi
    fi
    
    # Working directory status
    local status_output=$(git status --porcelain 2>/dev/null)
    if [ -n "$status_output" ]; then
        echo -e "\n${YELLOW}Working Directory Changes:${NC}"
        
        local staged=0
        local modified=0
        local untracked=0
        
        while IFS= read -r line; do
            local status_code="${line:0:2}"
            local file_name="${line:3}"
            
            case "$status_code" in
                "M "|"A "|"D "|"R "|"C ")
                    echo -e "${GREEN}✓${NC} Staged: $file_name"
                    ((staged++))
                    ;;
                " M"|" D")
                    echo -e "${YELLOW}!${NC} Modified: $file_name"
                    ((modified++))
                    ;;
                "??")
                    echo -e "${BLUE}?${NC} Untracked: $file_name"
                    ((untracked++))
                    ;;
                "MM"|"AM")
                    echo -e "${CYAN}±${NC} Partially staged: $file_name"
                    ;;
            esac
        done <<< "$status_output"
        
        echo -e "\n${CYAN}Summary:${NC} ${staged} staged, ${modified} modified, ${untracked} untracked"
    else
        echo -e "\n${GREEN}Working directory clean${NC}"
    fi
    
    # Recent commits
    echo -e "\n${WHITE}Recent Commits:${NC}"
    git log --oneline -5 2>/dev/null | while read -r commit; do
        echo -e "${GRAY}  $commit${NC}"
    done
}

# Add files to staging
stage_files() {
    local files=("$@")
    
    if [ ${#files[@]} -eq 0 ]; then
        echo -e "${BLUE}Interactive file staging${NC}"
        git add -i
        return
    fi
    
    echo -e "${BLUE}Staging files...${NC}"
    
    for file in "${files[@]}"; do
        if [ "$file" = "." ] || [ "$file" = "--all" ]; then
            git add .
            echo -e "${GREEN}✓${NC} All files staged"
            break
        elif [ -e "$file" ]; then
            git add "$file"
            echo -e "${GREEN}✓${NC} Staged: $file"
        else
            echo -e "${RED}✗${NC} File not found: $file"
        fi
    done
}

# Create commit
create_commit() {
    local message="$1"
    local amend="$2"
    
    if [ -z "$message" ]; then
        echo -ne "${CYAN}Enter commit message:${NC} "
        read -r message
    fi
    
    if [ -z "$message" ]; then
        echo -e "${RED}✗${NC} Commit message required"
        return 1
    fi
    
    echo -e "${BLUE}Creating commit...${NC}"
    
    # Show diff if enabled
    if [ "$SHOW_DIFF_IN_COMMIT" = "true" ]; then
        echo -e "\n${CYAN}Changes to be committed:${NC}"
        git diff --cached --stat
    fi
    
    # Commit command
    local commit_cmd="git commit -m \"$message\""
    if [ "$amend" = "amend" ]; then
        commit_cmd="git commit --amend -m \"$message\""
    fi
    
    if eval "$commit_cmd"; then
        echo -e "${GREEN}✓${NC} Commit created successfully"
        
        # Show commit info
        local commit_hash=$(git rev-parse --short HEAD)
        echo -e "${CYAN}Commit:${NC} $commit_hash"
        
        return 0
    else
        echo -e "${RED}✗${NC} Failed to create commit"
        return 1
    fi
}

# Branch management
manage_branches() {
    local action="$1"
    local branch_name="$2"
    local start_point="$3"
    
    case "$action" in
        list)
            echo -e "\n${BLUE}Local Branches:${NC}"
            git branch -v
            
            echo -e "\n${BLUE}Remote Branches:${NC}"
            git branch -r
            ;;
            
        create)
            if [ -z "$branch_name" ]; then
                echo -ne "${CYAN}Enter branch name:${NC} "
                read -r branch_name
            fi
            
            echo -e "${BLUE}Creating branch: $branch_name${NC}"
            
            local create_cmd="git branch $branch_name"
            if [ -n "$start_point" ]; then
                create_cmd="$create_cmd $start_point"
            fi
            
            if eval "$create_cmd"; then
                echo -e "${GREEN}✓${NC} Branch created: $branch_name"
            else
                echo -e "${RED}✗${NC} Failed to create branch"
            fi
            ;;
            
        switch)
            if [ -z "$branch_name" ]; then
                echo -e "${BLUE}Available branches:${NC}"
                git branch
                echo -ne "\n${CYAN}Enter branch name:${NC} "
                read -r branch_name
            fi
            
            echo -e "${BLUE}Switching to branch: $branch_name${NC}"
            
            if git checkout "$branch_name"; then
                echo -e "${GREEN}✓${NC} Switched to branch: $branch_name"
                show_repository_status
            else
                echo -e "${RED}✗${NC} Failed to switch branch"
            fi
            ;;
            
        delete)
            if [ -z "$branch_name" ]; then
                echo -e "${BLUE}Local branches:${NC}"
                git branch
                echo -ne "\n${CYAN}Enter branch name to delete:${NC} "
                read -r branch_name
            fi
            
            echo -e "${BLUE}Deleting branch: $branch_name${NC}"
            echo -ne "${YELLOW}Force delete? (y/N):${NC} "
            read -r force_delete
            
            local delete_cmd="git branch -d $branch_name"
            if [ "$force_delete" = "y" ] || [ "$force_delete" = "Y" ]; then
                delete_cmd="git branch -D $branch_name"
            fi
            
            if eval "$delete_cmd"; then
                echo -e "${GREEN}✓${NC} Branch deleted: $branch_name"
            else
                echo -e "${RED}✗${NC} Failed to delete branch"
            fi
            ;;
            
        merge)
            local current_branch=$(git branch --show-current)
            
            if [ -z "$branch_name" ]; then
                echo -e "${BLUE}Available branches:${NC}"
                git branch | grep -v "* $current_branch"
                echo -ne "\n${CYAN}Enter branch to merge into $current_branch:${NC} "
                read -r branch_name
            fi
            
            echo -e "${BLUE}Merging $branch_name into $current_branch${NC}"
            
            if git merge "$branch_name"; then
                echo -e "${GREEN}✓${NC} Branch merged successfully"
            else
                echo -e "${RED}✗${NC} Merge conflicts detected"
                echo -e "${YELLOW}Resolve conflicts and run: git commit${NC}"
            fi
            ;;
    esac
}

# Remote repository management
manage_remotes() {
    local action="$1"
    local remote_name="$2"
    local remote_url="$3"
    
    case "$action" in
        list)
            echo -e "\n${BLUE}Remote Repositories:${NC}"
            local remotes=$(git remote -v 2>/dev/null)
            if [ -n "$remotes" ]; then
                echo "$remotes"
            else
                echo -e "${YELLOW}No remotes configured${NC}"
            fi
            ;;
            
        add)
            if [ -z "$remote_name" ]; then
                echo -ne "${CYAN}Enter remote name (origin):${NC} "
                read -r remote_name
                remote_name="${remote_name:-origin}"
            fi
            
            if [ -z "$remote_url" ]; then
                echo -ne "${CYAN}Enter remote URL:${NC} "
                read -r remote_url
            fi
            
            echo -e "${BLUE}Adding remote: $remote_name${NC}"
            
            if git remote add "$remote_name" "$remote_url"; then
                echo -e "${GREEN}✓${NC} Remote added: $remote_name → $remote_url"
            else
                echo -e "${RED}✗${NC} Failed to add remote"
            fi
            ;;
            
        remove)
            if [ -z "$remote_name" ]; then
                echo -e "${BLUE}Current remotes:${NC}"
                git remote
                echo -ne "\n${CYAN}Enter remote name to remove:${NC} "
                read -r remote_name
            fi
            
            if git remote remove "$remote_name"; then
                echo -e "${GREEN}✓${NC} Remote removed: $remote_name"
            else
                echo -e "${RED}✗${NC} Failed to remove remote"
            fi
            ;;
            
        fetch)
            echo -e "${BLUE}Fetching from remotes...${NC}"
            if git fetch --all; then
                echo -e "${GREEN}✓${NC} Fetch completed"
            else
                echo -e "${RED}✗${NC} Fetch failed"
            fi
            ;;
            
        push)
            local current_branch=$(git branch --show-current)
            
            if [ -z "$remote_name" ]; then
                remote_name="origin"
            fi
            
            echo -e "${BLUE}Pushing $current_branch to $remote_name${NC}"
            
            if git push "$remote_name" "$current_branch"; then
                echo -e "${GREEN}✓${NC} Push completed"
            else
                echo -e "${RED}✗${NC} Push failed"
                echo -e "${YELLOW}Try: git push --set-upstream $remote_name $current_branch${NC}"
            fi
            ;;
            
        pull)
            if [ -z "$remote_name" ]; then
                remote_name="origin"
            fi
            
            local current_branch=$(git branch --show-current)
            echo -e "${BLUE}Pulling from $remote_name/$current_branch${NC}"
            
            local pull_cmd="git pull $remote_name $current_branch"
            if [ "$PULL_REBASE" = "true" ]; then
                pull_cmd="git pull --rebase $remote_name $current_branch"
            fi
            
            if eval "$pull_cmd"; then
                echo -e "${GREEN}✓${NC} Pull completed"
            else
                echo -e "${RED}✗${NC} Pull failed"
            fi
            ;;
    esac
}

# View commit history
view_history() {
    local format="$1"
    local count="${2:-10}"
    local branch="$3"
    
    echo -e "${BLUE}Commit History${NC}"
    if [ -n "$branch" ]; then
        echo -e "${CYAN}Branch: $branch${NC}"
    fi
    echo
    
    local log_cmd="git log --oneline -$count"
    if [ -n "$branch" ]; then
        log_cmd="$log_cmd $branch"
    fi
    
    case "$format" in
        detailed)
            git log --pretty=format:"%C(yellow)%h%C(reset) - %C(green)%an%C(reset), %C(blue)%ar%C(reset) : %s" -"$count" $branch
            ;;
        graph)
            git log --graph --pretty=format:"%C(yellow)%h%C(reset) - %C(green)%an%C(reset), %C(blue)%ar%C(reset) : %s" -"$count" $branch
            ;;
        stats)
            git log --stat -"$count" $branch
            ;;
        *)
            git log --oneline -"$count" $branch
            ;;
    esac
    
    echo
}

# Diff and comparison tools
show_diff() {
    local diff_type="$1"
    local target="$2"
    
    case "$diff_type" in
        staged)
            echo -e "${BLUE}Staged Changes:${NC}"
            git diff --cached
            ;;
        working)
            echo -e "${BLUE}Working Directory Changes:${NC}"
            git diff
            ;;
        commit)
            if [ -z "$target" ]; then
                echo -ne "${CYAN}Enter commit hash or reference:${NC} "
                read -r target
            fi
            echo -e "${BLUE}Commit Changes: $target${NC}"
            git show "$target"
            ;;
        branch)
            if [ -z "$target" ]; then
                echo -ne "${CYAN}Enter branch name to compare:${NC} "
                read -r target
            fi
            local current_branch=$(git branch --show-current)
            echo -e "${BLUE}Comparing $current_branch with $target:${NC}"
            git diff "$target".."$current_branch"
            ;;
        *)
            echo -e "${BLUE}All Changes:${NC}"
            git diff HEAD
            ;;
    esac
}

# Stash management
manage_stash() {
    local action="$1"
    local stash_name="$2"
    
    case "$action" in
        list)
            echo -e "\n${BLUE}Stashed Changes:${NC}"
            git stash list
            ;;
        save)
            if [ -z "$stash_name" ]; then
                echo -ne "${CYAN}Enter stash message (optional):${NC} "
                read -r stash_name
            fi
            
            local stash_cmd="git stash"
            if [ -n "$stash_name" ]; then
                stash_cmd="$stash_cmd save \"$stash_name\""
            fi
            
            if eval "$stash_cmd"; then
                echo -e "${GREEN}✓${NC} Changes stashed"
            else
                echo -e "${RED}✗${NC} Stash failed"
            fi
            ;;
        apply)
            echo -e "${BLUE}Available stashes:${NC}"
            git stash list
            
            if [ -z "$stash_name" ]; then
                echo -ne "${CYAN}Enter stash index (0):${NC} "
                read -r stash_name
                stash_name="${stash_name:-0}"
            fi
            
            if git stash apply "stash@{$stash_name}"; then
                echo -e "${GREEN}✓${NC} Stash applied"
            else
                echo -e "${RED}✗${NC} Stash apply failed"
            fi
            ;;
        drop)
            echo -e "${BLUE}Available stashes:${NC}"
            git stash list
            
            if [ -z "$stash_name" ]; then
                echo -ne "${CYAN}Enter stash index to drop:${NC} "
                read -r stash_name
            fi
            
            if git stash drop "stash@{$stash_name}"; then
                echo -e "${GREEN}✓${NC} Stash dropped"
            else
                echo -e "${RED}✗${NC} Stash drop failed"
            fi
            ;;
    esac
}

# Repository management
manage_repositories() {
    echo -e "\n${BLUE}Managed Repositories:${NC}"
    
    if [ ! -s "$REPOS_DIR/repositories.db" ]; then
        echo -e "${YELLOW}No repositories tracked${NC}"
        return
    fi
    
    local count=1
    while IFS='|' read -r path url timestamp status; do
        local repo_name=$(basename "$path")
        local date_added=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")
        
        echo -e "${WHITE}$count.${NC} $repo_name"
        echo -e "   ${CYAN}Path:${NC} $path"
        echo -e "   ${CYAN}URL:${NC} $url"
        echo -e "   ${CYAN}Added:${NC} $date_added"
        echo -e "   ${CYAN}Status:${NC} $status"
        
        # Check if repository still exists and is accessible
        if [ -d "$path/.git" ]; then
            local current_branch=$(git -C "$path" branch --show-current 2>/dev/null)
            if [ -n "$current_branch" ]; then
                echo -e "   ${CYAN}Branch:${NC} $current_branch"
            fi
        else
            echo -e "   ${RED}Repository not accessible${NC}"
        fi
        
        echo
        ((count++))
    done < "$REPOS_DIR/repositories.db"
}

# Git configuration
configure_git() {
    echo -e "${BLUE}Git Configuration${NC}"
    echo
    echo -e "${WHITE}1.${NC} User configuration"
    echo -e "${WHITE}2.${NC} Editor settings"
    echo -e "${WHITE}3.${NC} Merge tool"
    echo -e "${WHITE}4.${NC} SSH keys"
    echo -e "${WHITE}5.${NC} Global gitignore"
    echo -e "${WHITE}q.${NC} Back to main menu"
    echo
    
    echo -ne "${YELLOW}Select option:${NC} "
    read -r config_choice
    
    case "$config_choice" in
        1)
            setup_git_user
            ;;
        2)
            echo -ne "${CYAN}Enter preferred editor (nano/vim/code):${NC} "
            read -r editor
            if [ -n "$editor" ]; then
                git config --global core.editor "$editor"
                echo -e "${GREEN}✓${NC} Editor set to: $editor"
            fi
            ;;
        3)
            echo -ne "${CYAN}Enter merge tool (vimdiff/meld/kdiff3):${NC} "
            read -r merge_tool
            if [ -n "$merge_tool" ]; then
                git config --global merge.tool "$merge_tool"
                echo -e "${GREEN}✓${NC} Merge tool set to: $merge_tool"
            fi
            ;;
        4)
            setup_ssh_keys
            ;;
        5)
            setup_global_gitignore
            ;;
    esac
}

# Setup SSH keys
setup_ssh_keys() {
    echo -e "${BLUE}SSH Key Management${NC}"
    
    local ssh_dir="$HOME/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Check existing keys
    echo -e "\n${CYAN}Existing SSH Keys:${NC}"
    if ls "$ssh_dir"/id_* >/dev/null 2>&1; then
        ls -la "$ssh_dir"/id_*
    else
        echo -e "${YELLOW}No SSH keys found${NC}"
    fi
    
    echo
    echo -e "${WHITE}1.${NC} Generate new SSH key"
    echo -e "${WHITE}2.${NC} Add key to SSH agent"
    echo -e "${WHITE}3.${NC} Show public key"
    echo -e "${WHITE}q.${NC} Back"
    echo
    
    echo -ne "${YELLOW}Select option:${NC} "
    read -r ssh_choice
    
    case "$ssh_choice" in
        1)
            echo -ne "${CYAN}Enter your email:${NC} "
            read -r email
            if [ -n "$email" ]; then
                ssh-keygen -t "$SSH_KEY_TYPE" -C "$email"
                echo -e "${GREEN}✓${NC} SSH key generated"
            fi
            ;;
        2)
            eval "$(ssh-agent -s)"
            ssh-add "$ssh_dir/id_$SSH_KEY_TYPE"
            echo -e "${GREEN}✓${NC} Key added to SSH agent"
            ;;
        3)
            if [ -f "$ssh_dir/id_$SSH_KEY_TYPE.pub" ]; then
                echo -e "\n${CYAN}Public Key:${NC}"
                cat "$ssh_dir/id_$SSH_KEY_TYPE.pub"
                echo
                echo -e "${YELLOW}Copy this key to your Git provider (GitHub, GitLab, etc.)${NC}"
            else
                echo -e "${RED}✗${NC} Public key not found"
            fi
            ;;
    esac
}

# Setup global gitignore
setup_global_gitignore() {
    local global_gitignore="$HOME/.gitignore_global"
    
    echo -e "${BLUE}Setting up global gitignore...${NC}"
    
    cat > "$global_gitignore" << 'EOF'
# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Editor files
*~
*.swp
*.swo
.vscode/
.idea/

# Log files
*.log
*.out

# Temporary files
*.tmp
*.temp

# Environment files
.env
.env.local
.env.production

# Dependencies
node_modules/
bower_components/

# Build outputs
dist/
build/
*.min.js
*.min.css
EOF
    
    git config --global core.excludesfile "$global_gitignore"
    echo -e "${GREEN}✓${NC} Global gitignore configured: $global_gitignore"
}

# Main menu
main_menu() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                  ${WHITE}BluejayLinux Git Manager${PURPLE}                       ║${NC}"
    echo -e "${PURPLE}║               ${CYAN}Professional Version Control GUI${PURPLE}                 ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Check Git status
    if command -v git >/dev/null; then
        local git_version=$(git --version | cut -d' ' -f3)
        echo -e "${WHITE}Git version:${NC} $git_version"
        
        if [ -d ".git" ]; then
            local current_repo=$(basename "$(pwd)")
            local current_branch=$(git branch --show-current 2>/dev/null)
            echo -e "${WHITE}Current repository:${NC} $current_repo"
            echo -e "${WHITE}Current branch:${NC} $current_branch"
        else
            echo -e "${YELLOW}Not in a Git repository${NC}"
        fi
    else
        echo -e "${RED}Git not installed${NC}"
    fi
    echo
    
    echo -e "${WHITE}Repository Management:${NC}"
    echo -e "${WHITE}1.${NC} Clone repository"
    echo -e "${WHITE}2.${NC} Initialize repository"
    echo -e "${WHITE}3.${NC} Repository status"
    echo -e "${WHITE}4.${NC} Manage repositories"
    echo
    echo -e "${WHITE}File Operations:${NC}"
    echo -e "${WHITE}5.${NC} Stage files"
    echo -e "${WHITE}6.${NC} Create commit"
    echo -e "${WHITE}7.${NC} View differences"
    echo -e "${WHITE}8.${NC} Stash management"
    echo
    echo -e "${WHITE}Branch Operations:${NC}"
    echo -e "${WHITE}9.${NC} Branch management"
    echo -e "${WHITE}10.${NC} View history"
    echo
    echo -e "${WHITE}Remote Operations:${NC}"
    echo -e "${WHITE}11.${NC} Remote management"
    echo
    echo -e "${WHITE}Configuration:${NC}"
    echo -e "${WHITE}12.${NC} Git configuration"
    echo -e "${WHITE}q.${NC} Quit"
    echo
}

# Main function
main() {
    create_directories
    load_settings
    
    if [ $# -gt 0 ]; then
        case "$1" in
            --clone)
                clone_repository "$2" "$3" "$4"
                ;;
            --init)
                init_repository "$2" "$3"
                ;;
            --status)
                show_repository_status
                ;;
            --add)
                shift
                stage_files "$@"
                ;;
            --commit)
                create_commit "$2" "$3"
                ;;
            --push)
                manage_remotes push "$2"
                ;;
            --pull)
                manage_remotes pull "$2"
                ;;
            --help|-h)
                echo "BluejayLinux Git Manager"
                echo "Usage: $0 [options] [parameters]"
                echo "  --clone <url> [dir] [branch]  Clone repository"
                echo "  --init [dir] [bare]           Initialize repository"
                echo "  --status                      Show repository status"
                echo "  --add <files...>              Stage files"
                echo "  --commit <message> [amend]    Create commit"
                echo "  --push [remote]               Push to remote"
                echo "  --pull [remote]               Pull from remote"
                ;;
        esac
        return
    fi
    
    # Check Git installation first
    if ! check_git_installation; then
        return 1
    fi
    
    # Interactive mode
    while true; do
        main_menu
        echo -ne "${YELLOW}Select option:${NC} "
        read -r choice
        
        case "$choice" in
            1)
                echo -ne "${CYAN}Repository URL:${NC} "
                read -r repo_url
                echo -ne "${CYAN}Target directory (optional):${NC} "
                read -r target_dir
                echo -ne "${CYAN}Branch (optional):${NC} "
                read -r branch
                if [ -n "$repo_url" ]; then
                    clone_repository "$repo_url" "$target_dir" "$branch"
                fi
                ;;
            2)
                echo -ne "${CYAN}Repository path (current dir):${NC} "
                read -r repo_path
                repo_path="${repo_path:-.}"
                echo -ne "${CYAN}Create bare repository? (y/N):${NC} "
                read -r bare_opt
                local bare="false"
                [ "$bare_opt" = "y" ] && bare="true"
                init_repository "$repo_path" "$bare"
                ;;
            3)
                show_repository_status
                ;;
            4)
                manage_repositories
                ;;
            5)
                echo -ne "${CYAN}Files to stage (. for all, or specific files):${NC} "
                read -r files_input
                if [ -n "$files_input" ]; then
                    # Convert space-separated string to array
                    read -ra files_array <<< "$files_input"
                    stage_files "${files_array[@]}"
                fi
                ;;
            6)
                echo -ne "${CYAN}Commit message:${NC} "
                read -r commit_msg
                echo -ne "${CYAN}Amend last commit? (y/N):${NC} "
                read -r amend_opt
                local amend=""
                [ "$amend_opt" = "y" ] && amend="amend"
                create_commit "$commit_msg" "$amend"
                ;;
            7)
                echo -e "${CYAN}Diff options:${NC}"
                echo -e "${WHITE}1.${NC} Working directory"
                echo -e "${WHITE}2.${NC} Staged changes"
                echo -e "${WHITE}3.${NC} Specific commit"
                echo -e "${WHITE}4.${NC} Compare branches"
                echo -ne "${YELLOW}Select:${NC} "
                read -r diff_choice
                
                case "$diff_choice" in
                    1) show_diff working ;;
                    2) show_diff staged ;;
                    3) show_diff commit ;;
                    4) show_diff branch ;;
                esac
                ;;
            8)
                echo -e "${CYAN}Stash operations:${NC}"
                echo -e "${WHITE}1.${NC} List stashes"
                echo -e "${WHITE}2.${NC} Save stash"
                echo -e "${WHITE}3.${NC} Apply stash"
                echo -e "${WHITE}4.${NC} Drop stash"
                echo -ne "${YELLOW}Select:${NC} "
                read -r stash_choice
                
                case "$stash_choice" in
                    1) manage_stash list ;;
                    2) manage_stash save ;;
                    3) manage_stash apply ;;
                    4) manage_stash drop ;;
                esac
                ;;
            9)
                echo -e "${CYAN}Branch operations:${NC}"
                echo -e "${WHITE}1.${NC} List branches"
                echo -e "${WHITE}2.${NC} Create branch"
                echo -e "${WHITE}3.${NC} Switch branch"
                echo -e "${WHITE}4.${NC} Delete branch"
                echo -e "${WHITE}5.${NC} Merge branch"
                echo -ne "${YELLOW}Select:${NC} "
                read -r branch_choice
                
                case "$branch_choice" in
                    1) manage_branches list ;;
                    2) manage_branches create ;;
                    3) manage_branches switch ;;
                    4) manage_branches delete ;;
                    5) manage_branches merge ;;
                esac
                ;;
            10)
                echo -ne "${CYAN}Number of commits (10):${NC} "
                read -r commit_count
                commit_count="${commit_count:-10}"
                echo -e "${CYAN}Format options: oneline/detailed/graph/stats${NC}"
                echo -ne "${CYAN}Format (oneline):${NC} "
                read -r format
                format="${format:-oneline}"
                view_history "$format" "$commit_count"
                ;;
            11)
                echo -e "${CYAN}Remote operations:${NC}"
                echo -e "${WHITE}1.${NC} List remotes"
                echo -e "${WHITE}2.${NC} Add remote"
                echo -e "${WHITE}3.${NC} Remove remote"
                echo -e "${WHITE}4.${NC} Fetch"
                echo -e "${WHITE}5.${NC} Push"
                echo -e "${WHITE}6.${NC} Pull"
                echo -ne "${YELLOW}Select:${NC} "
                read -r remote_choice
                
                case "$remote_choice" in
                    1) manage_remotes list ;;
                    2) manage_remotes add ;;
                    3) manage_remotes remove ;;
                    4) manage_remotes fetch ;;
                    5) manage_remotes push ;;
                    6) manage_remotes pull ;;
                esac
                ;;
            12)
                configure_git
                ;;
            q|Q)
                echo -e "${GREEN}Git Manager session saved${NC}"
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        echo
        echo -ne "${GRAY}Press Enter to continue...${NC}"
        read -r
        clear
    done
}

# Run main function
main "$@"