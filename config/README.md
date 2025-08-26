# config/

This folder stores Traefik configuration files.

- `traefik.yaml`: static configuration, generated once from template during setup.  
  ⚠️ This file should be reviewed and edited according to your environment needs.  

- `dynamic.yaml`: dynamic configuration, initially generated from template.  
  ⚠️ In production, it is recommended to customize and maintain this file manually.  

The templates under `templates/` serve only as a starting point.
