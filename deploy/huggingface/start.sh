
name: Deploy to Hugging Face

on:
  workflow_dispatch:
  push:
    branches: [main]
    paths:
      - "deploy/huggingface/**"
      - "vendor/ohamlab/**"
      - ".github/workflows/deploy-huggingface.yml"

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Prepare Hugging Face Space files
        run: |
          mkdir -p hf-space
          cp deploy/huggingface/Dockerfile hf-space/Dockerfile
          cp deploy/huggingface/start.sh hf-space/start.sh
          cp deploy/huggingface/nginx.conf hf-space/nginx.conf

          cat > hf-space/README.md <<'EOF'
          ---
          title: OhamLab Harness
          emoji: 🤖
          sdk: docker
          app_port: 7860
          ---
          EOF

      - name: Push to Hugging Face Space
        env:
          HF_TOKEN: ${{ secrets.HF_TOKEN }}
          HF_SPACE: ${{ vars.HF_SPACE }}
        run: |
          git clone "https://oauth2:${HF_TOKEN}@huggingface.co/spaces/${HF_SPACE}" hf-repo
          cp hf-space/* hf-repo/
          cd hf-repo
          git config user.name "github-actions"
          git config user.email "github-actions@users.noreply.github.com"
          git add Dockerfile start.sh nginx.conf README.md
          if ! git diff --cached --quiet; then
            git commit -m "Deploy OhamLab Harness from GitHub"
            git push
          fi
