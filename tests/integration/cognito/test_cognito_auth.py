#!/usr/bin/env python3
"""
Test Cognito Authentication
Simulates user login flow and token validation
"""

import boto3
import argparse
import sys
import json
import base64
import hmac
import hashlib
from getpass import getpass

class CognitoAuthTester:
    def __init__(self, user_pool_id, client_id, client_secret=None):
        self.client = boto3.client('cognito-idp')
        self.user_pool_id = user_pool_id
        self.client_id = client_id
        self.client_secret = client_secret
    
    def _get_secret_hash(self, username):
        """Calculate SECRET_HASH for Cognito"""
        if not self.client_secret:
            return None
        
        message = bytes(username + self.client_id, 'utf-8')
        secret = bytes(self.client_secret, 'utf-8')
        dig = hmac.new(secret, msg=message, digestmod=hashlib.sha256).digest()
        return base64.b64encode(dig).decode()
    
    def signup(self, email, password, name, patient_id, phone):
        """Sign up a new user"""
        try:
            print(f"\n🔹 Signing up user: {email}")
            
            params = {
                'ClientId': self.client_id,
                'Username': email,
                'Password': password,
                'UserAttributes': [
                    {'Name': 'email', 'Value': email},
                    {'Name': 'name', 'Value': name},
                    {'Name': 'custom:patient_id', 'Value': patient_id},
                    {'Name': 'phone_number', 'Value': phone}
                ]
            }
            
            if self.client_secret:
                params['SecretHash'] = self._get_secret_hash(email)
            
            response = self.client.sign_up(**params)
            
            print(f"✅ Sign up successful!")
            print(f"   User Sub: {response['UserSub']}")
            print(f"   User Confirmed: {response['UserConfirmed']}")
            
            if not response['UserConfirmed']:
                print("\n⚠️  User needs to confirm email")
                print(f"   Check email for verification code")
            
            return response
        
        except Exception as e:
            print(f"❌ Sign up failed: {e}")
            return None
    
    def confirm_signup(self, email, confirmation_code):
        """Confirm user signup with verification code"""
        try:
            print(f"\n🔹 Confirming signup for: {email}")
            
            params = {
                'ClientId': self.client_id,
                'Username': email,
                'ConfirmationCode': confirmation_code
            }
            
            if self.client_secret:
                params['SecretHash'] = self._get_secret_hash(email)
            
            self.client.confirm_sign_up(**params)
            
            print(f"✅ Email confirmed successfully!")
            return True
        
        except Exception as e:
            print(f"❌ Confirmation failed: {e}")
            return False
    
    def login(self, email, password):
        """Login user and get tokens"""
        try:
            print(f"\n🔹 Logging in user: {email}")
            
            params = {
                'AuthFlow': 'USER_PASSWORD_AUTH',
                'ClientId': self.client_id,
                'AuthParameters': {
                    'USERNAME': email,
                    'PASSWORD': password
                }
            }
            
            if self.client_secret:
                params['AuthParameters']['SECRET_HASH'] = self._get_secret_hash(email)
            
            response = self.client.initiate_auth(**params)
            
            # Check if we need to handle challenges
            if 'ChallengeName' in response:
                challenge = response['ChallengeName']
                print(f"\n⚠️  Challenge required: {challenge}")
                
                if challenge == 'NEW_PASSWORD_REQUIRED':
                    print("   User must change password")
                    return self._handle_new_password_challenge(response, email)
                elif challenge == 'SMS_MFA' or challenge == 'SOFTWARE_TOKEN_MFA':
                    print("   MFA required")
                    return self._handle_mfa_challenge(response, email)
                else:
                    print(f"   Unhandled challenge: {challenge}")
                    return None
            
            # Successful authentication
            auth_result = response['AuthenticationResult']
            
            print(f"✅ Login successful!")
            print(f"\n📋 Tokens received:")
            print(f"   ID Token: {auth_result['IdToken'][:50]}...")
            print(f"   Access Token: {auth_result['AccessToken'][:50]}...")
            print(f"   Refresh Token: {auth_result['RefreshToken'][:50]}...")
            print(f"   Expires in: {auth_result['ExpiresIn']} seconds")
            
            return auth_result
        
        except Exception as e:
            print(f"❌ Login failed: {e}")
            return None
    
    def _handle_new_password_challenge(self, challenge_response, email):
        """Handle NEW_PASSWORD_REQUIRED challenge"""
        print("\n🔒 New password required")
        new_password = getpass("Enter new password: ")
        
        try:
            params = {
                'ClientId': self.client_id,
                'ChallengeName': 'NEW_PASSWORD_REQUIRED',
                'Session': challenge_response['Session'],
                'ChallengeResponses': {
                    'USERNAME': email,
                    'NEW_PASSWORD': new_password
                }
            }
            
            if self.client_secret:
                params['ChallengeResponses']['SECRET_HASH'] = self._get_secret_hash(email)
            
            response = self.client.respond_to_auth_challenge(**params)
            
            if 'AuthenticationResult' in response:
                print("✅ Password changed and logged in successfully!")
                return response['AuthenticationResult']
            else:
                print("⚠️  Additional challenges required")
                return None
        
        except Exception as e:
            print(f"❌ Password change failed: {e}")
            return None
    
    def _handle_mfa_challenge(self, challenge_response, email):
        """Handle MFA challenge"""
        mfa_code = input("Enter MFA code: ")
        
        try:
            params = {
                'ClientId': self.client_id,
                'ChallengeName': challenge_response['ChallengeName'],
                'Session': challenge_response['Session'],
                'ChallengeResponses': {
                    'USERNAME': email,
                    'MFA_CODE': mfa_code
                }
            }
            
            if self.client_secret:
                params['ChallengeResponses']['SECRET_HASH'] = self._get_secret_hash(email)
            
            response = self.client.respond_to_auth_challenge(**params)
            
            if 'AuthenticationResult' in response:
                print("✅ MFA verified and logged in successfully!")
                return response['AuthenticationResult']
            else:
                print("⚠️  Additional challenges required")
                return None
        
        except Exception as e:
            print(f"❌ MFA verification failed: {e}")
            return None
    
    def refresh_token(self, refresh_token):
        """Refresh access token using refresh token"""
        try:
            print(f"\n🔹 Refreshing tokens...")
            
            params = {
                'AuthFlow': 'REFRESH_TOKEN_AUTH',
                'ClientId': self.client_id,
                'AuthParameters': {
                    'REFRESH_TOKEN': refresh_token
                }
            }
            
            response = self.client.initiate_auth(**params)
            auth_result = response['AuthenticationResult']
            
            print(f"✅ Tokens refreshed successfully!")
            print(f"   New ID Token: {auth_result['IdToken'][:50]}...")
            print(f"   New Access Token: {auth_result['AccessToken'][:50]}...")
            
            return auth_result
        
        except Exception as e:
            print(f"❌ Token refresh failed: {e}")
            return None
    
    def get_user_info(self, access_token):
        """Get user information using access token"""
        try:
            print(f"\n🔹 Getting user information...")
            
            response = self.client.get_user(
                AccessToken=access_token
            )
            
            print(f"✅ User info retrieved!")
            print(f"\n👤 User Details:")
            print(f"   Username: {response['Username']}")
            print(f"   User Attributes:")
            for attr in response['UserAttributes']:
                print(f"      {attr['Name']}: {attr['Value']}")
            
            return response
        
        except Exception as e:
            print(f"❌ Failed to get user info: {e}")
            return None
    
    def logout(self, access_token):
        """Global sign out (invalidate all tokens)"""
        try:
            print(f"\n🔹 Logging out...")
            
            self.client.global_sign_out(
                AccessToken=access_token
            )
            
            print(f"✅ Logged out successfully!")
            return True
        
        except Exception as e:
            print(f"❌ Logout failed: {e}")
            return False
    
    def change_password(self, access_token, old_password, new_password):
        """Change user password"""
        try:
            print(f"\n🔹 Changing password...")
            
            self.client.change_password(
                PreviousPassword=old_password,
                ProposedPassword=new_password,
                AccessToken=access_token
            )
            
            print(f"✅ Password changed successfully!")
            return True
        
        except Exception as e:
            print(f"❌ Password change failed: {e}")
            return False

def main():
    parser = argparse.ArgumentParser(description='Test Cognito Authentication')
    parser.add_argument('--user-pool-id', required=True, help='Cognito User Pool ID')
    parser.add_argument('--client-id', required=True, help='Cognito Client ID')
    parser.add_argument('--client-secret', help='Cognito Client Secret (if applicable)')
    parser.add_argument('--action', required=True, 
                       choices=['signup', 'confirm', 'login', 'refresh', 'info', 'logout', 'change-password'],
                       help='Action to perform')
    parser.add_argument('--email', help='User email')
    parser.add_argument('--password', help='User password (will prompt if not provided)')
    parser.add_argument('--name', help='User name (for signup)')
    parser.add_argument('--patient-id', help='Patient ID (for signup)')
    parser.add_argument('--phone', help='Phone number (for signup)')
    parser.add_argument('--code', help='Verification code (for confirm)')
    parser.add_argument('--token', help='Access token or refresh token')
    
    args = parser.parse_args()
    
    print("=" * 70)
    print("Cognito Authentication Tester")
    print("=" * 70)
    
    tester = CognitoAuthTester(
        user_pool_id=args.user_pool_id,
        client_id=args.client_id,
        client_secret=args.client_secret
    )
    
    if args.action == 'signup':
        if not all([args.email, args.name, args.patient_id, args.phone]):
            print("❌ Error: signup requires --email, --name, --patient-id, and --phone")
            sys.exit(1)
        
        password = args.password or getpass("Enter password: ")
        tester.signup(args.email, password, args.name, args.patient_id, args.phone)
    
    elif args.action == 'confirm':
        if not args.email or not args.code:
            print("❌ Error: confirm requires --email and --code")
            sys.exit(1)
        
        tester.confirm_signup(args.email, args.code)
    
    elif args.action == 'login':
        if not args.email:
            print("❌ Error: login requires --email")
            sys.exit(1)
        
        password = args.password or getpass("Enter password: ")
        result = tester.login(args.email, password)
        
        if result:
            print("\n💾 Save these tokens for future use:")
            print(f"\nAccess Token:\n{result['AccessToken']}")
            print(f"\nRefresh Token:\n{result['RefreshToken']}")
    
    elif args.action == 'refresh':
        if not args.token:
            print("❌ Error: refresh requires --token (refresh token)")
            sys.exit(1)
        
        tester.refresh_token(args.token)
    
    elif args.action == 'info':
        if not args.token:
            print("❌ Error: info requires --token (access token)")
            sys.exit(1)
        
        tester.get_user_info(args.token)
    
    elif args.action == 'logout':
        if not args.token:
            print("❌ Error: logout requires --token (access token)")
            sys.exit(1)
        
        tester.logout(args.token)
    
    elif args.action == 'change-password':
        if not args.token:
            print("❌ Error: change-password requires --token (access token)")
            sys.exit(1)
        
        old_password = getpass("Enter old password: ")
        new_password = getpass("Enter new password: ")
        tester.change_password(args.token, old_password, new_password)
    
    print("\n" + "=" * 70)

if __name__ == "__main__":
    main()