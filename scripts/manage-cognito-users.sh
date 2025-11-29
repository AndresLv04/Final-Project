#!/bin/bash

# Cognito User Management Script
# Manage users in Healthcare Lab Cognito User Pool

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-dev}
PROJECT_NAME="healthcare-lab-platform"
USER_POOL_ID=""

# Resolve environment directory (optional, por si luego tienes staging/prod)
get_env_dir() {
  case "$ENVIRONMENT" in
    dev) echo "development" ;;
    # staging) echo "staging" ;;
    # prod) echo "production" ;;
    *) echo "$ENVIRONMENT" ;;
  esac
}

# Function to get User Pool ID
get_user_pool_id() {
    if [ -z "$USER_POOL_ID" ]; then
        echo -e "${YELLOW}Getting User Pool ID...${NC}"
        
        ENV_DIR=$(get_env_dir)

        # Asumimos que el script se ejecuta desde la raíz del repo
        USER_POOL_ID=$(
          cd "environments/${ENV_DIR}" && \
          tofu output -raw cognito_user_pool_id 2>/dev/null || echo ""
        )
        
        if [ -z "$USER_POOL_ID" ]; then
            echo -e "${RED}Error: Could not get User Pool ID${NC}"
            echo "Make sure Cognito is deployed:"
            echo "  cd environments/${ENV_DIR}"
            echo "  tofu apply -var-file=\"${ENVIRONMENT}.tfvars\" -target=module.cognito"
            exit 1
        fi
        
        echo -e "${GREEN}✓ User Pool ID: $USER_POOL_ID${NC}"
    fi
}

# Function to create a user
create_user() {
    local email=$1
    local name=$2
    local patient_id=$3
    local phone=$4
    
    echo -e "${YELLOW}Creating user: $email${NC}"
    
    # Generate temporary password
    local temp_password
    # Generate temporary password (always meets policy)
    temp_password="$(openssl rand -base64 9)@1aA"

    
    # Create user
    aws cognito-idp admin-create-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "$email" \
    --user-attributes \
        "Name=email,Value=$email" \
        "Name=email_verified,Value=true" \
        "Name=name,Value=$name" \
        "Name=custom:patient_id,Value=$patient_id" \
        "Name=phone_number,Value=$phone" \
    --temporary-password "$temp_password" \
    --message-action SUPPRESS

    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ User created successfully${NC}"
        echo -e "  Email: $email"
        echo -e "  Name: $name"
        echo -e "  Patient ID: $patient_id"
        echo -e "  Temporary Password: $temp_password"
        echo ""
        echo -e "${YELLOW}IMPORTANT: Save this temporary password and send it to the user${NC}"
        
        # Add to patients group
        aws cognito-idp admin-add-user-to-group \
            --user-pool-id "$USER_POOL_ID" \
            --username "$email" \
            --group-name patients
        
        echo -e "${GREEN}✓ Added to 'patients' group${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to create user${NC}"
        return 1
    fi
}

# Function to list users
list_users() {
    echo -e "${YELLOW}Listing all users...${NC}"
    
    aws cognito-idp list-users \
        --user-pool-id "$USER_POOL_ID" \
        --query 'Users[*].[Username,UserStatus,Enabled,UserCreateDate]' \
        --output table
}

# Function to get user details
get_user() {
    local email=$1
    
    echo -e "${YELLOW}Getting user details: $email${NC}"
    
    aws cognito-idp admin-get-user \
        --user-pool-id "$USER_POOL_ID" \
        --username "$email"
}

# Function to delete user
delete_user() {
    local email=$1
    
    echo -e "${YELLOW}Deleting user: $email${NC}"
    
    read -p "Are you sure you want to delete $email? (yes/no): " confirm
    
    if [ "$confirm" == "yes" ]; then
        aws cognito-idp admin-delete-user \
            --user-pool-id "$USER_POOL_ID" \
            --username "$email"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ User deleted successfully${NC}"
        else
            echo -e "${RED}✗ Failed to delete user${NC}"
        fi
    else
        echo "Deletion cancelled"
    fi
}

# Function to reset password
reset_password() {
    local email=$1
    
    echo -e "${YELLOW}Resetting password for: $email${NC}"
    
    # Generar nueva contraseña temporal que SIEMPRE cumpla la política
    local temp_password
    temp_password="$(openssl rand -base64 9)@1aA"

    # Ejecutar el comando dentro de un if para que set -e no nos mate el script
    if aws cognito-idp admin-set-user-password \
        --user-pool-id "$USER_POOL_ID" \
        --username "$email" \
        --password "$temp_password" \
        --no-permanent; then
        
        echo -e "${GREEN}✓ Password reset successfully${NC}"
        echo -e "  New temporary password: $temp_password"
        echo -e "${YELLOW}IMPORTANT: Send this password to the user${NC}"
    else
        echo -e "${RED}✗ Failed to reset password${NC}"
    fi
}



# Function to enable/disable user
toggle_user() {
    local email=$1
    local action=$2  # enable or disable
    
    echo -e "${YELLOW}${action^}ing user: $email${NC}"
    
    if [ "$action" == "enable" ]; then
        aws cognito-idp admin-enable-user \
            --user-pool-id "$USER_POOL_ID" \
            --username "$email"
    else
        aws cognito-idp admin-disable-user \
            --user-pool-id "$USER_POOL_ID" \
            --username "$email"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ User ${action}d successfully${NC}"
    else
        echo -e "${RED}✗ Failed to ${action} user${NC}"
    fi
}

# Function to create test users
create_test_users() {
    echo -e "${YELLOW}Creating test users...${NC}"
    echo ""
    
    # Test user data matching our sample patients
    declare -a users=(
        "andreslopezv04@gmail.com|John Smith|P123456|+15555550101"
        "intercambiouag@gmail.com|Maria Garcia|P234567|+15555550102"
        "messi.andres1404@gmail.com|James Wilson|P345678|+15555550103"
    )
    
    for user_data in "${users[@]}"; do
        IFS='|' read -r email name patient_id phone <<< "$user_data"
        create_user "$email" "$name" "$patient_id" "$phone"
        echo ""
    done
    
    echo -e "${GREEN}✓ All test users created${NC}"
}

# Function to show menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "  Cognito User Management"
    echo "=========================================="
    echo "1. Create user"
    echo "2. List all users"
    echo "3. Get user details"
    echo "4. Delete user"
    echo "5. Reset password"
    echo "6. Enable user"
    echo "7. Disable user"
    echo "8. Create test users"
    echo "9. Exit"
    echo "=========================================="
    echo -n "Select option: "
}

# Main script
main() {
    echo "=========================================="
    echo "Cognito User Management Script"
    echo "=========================================="
    echo "Environment: $ENVIRONMENT"
    echo ""
    
    get_user_pool_id
    
    while true; do
        show_menu
        read option
        
        case $option in
            1)
                echo ""
                read -p "Email: " email
                read -p "Name: " name
                read -p "Patient ID: " patient_id
                read -p "Phone (+15551234567): " phone
                create_user "$email" "$name" "$patient_id" "$phone"
                ;;
            2)
                echo ""
                list_users
                ;;
            3)
                echo ""
                read -p "Email: " email
                get_user "$email"
                ;;
            4)
                echo ""
                read -p "Email: " email
                delete_user "$email"
                ;;
            5)
                echo ""
                read -p "Email: " email
                reset_password "$email"
                ;;
            6)
                echo ""
                read -p "Email: " email
                toggle_user "$email" "enable"
                ;;
            7)
                echo ""
                read -p "Email: " email
                toggle_user "$email" "disable"
                ;;
            8)
                echo ""
                create_test_users
                ;;
            9)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main
main
