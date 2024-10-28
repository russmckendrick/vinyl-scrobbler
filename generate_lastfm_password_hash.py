import pylast
import getpass

# Securely ask for password (input won't be visible when typing)
password = getpass.getpass("Enter your password: ")

# Generate hash
password_hash = pylast.md5(password)
print("MD5 Hash:", password_hash)