# Managed code save permission errors

When the admin editor cannot save a file because the API process user lacks write access, fix the file or directory permissions from a terminal:

1. **Give write permission on the specific file** (adds write for the owner):
   ```bash
   sudo chmod u+w /home/garderobus/garderobus_back/api/run.sh
   ```
2. **Give write permission on the API folder** (helps if the directory itself blocks writes):
   ```bash
   sudo chmod u+w /home/garderobus/garderobus_back/api
   ```
3. **Change ownership to the API user** (makes `garderobus` the owner, if desired):
   ```bash
   sudo chown garderobus:garderobus /home/garderobus/garderobus_back/api/run.sh
   ```

Choose the option that matches your security requirements. If you edit as `root` but the API runs as `garderobus`, you still need to grant write access to the API user for saves to succeed.
