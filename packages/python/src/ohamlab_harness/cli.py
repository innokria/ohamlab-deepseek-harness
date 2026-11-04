"""OhamLab Harness command-line interface."""
import argparse
import sys
from pathlib import Path
from . import __version__
from .installer import install
from .runtime import default_home, executable, start


def main(argv=None):
    parser = argparse.ArgumentParser(prog="ohamlab-harness")
    parser.add_argument("--version", action="version", version=__version__)
    commands = parser.add_subparsers(dest="command", required=True)
    p = commands.add_parser("install", help="Install and build Harness from tagged sources")
    p.add_argument("--home")
    p.add_argument("--repo")
    p.add_argument("--harness-tag")
    p.add_argument("--integration-tag")
    p.add_argument("--force", action="store_true")
    p = commands.add_parser("start", help="Start Harness web UI")
    p.add_argument("--home")
    p.add_argument("--host")
    p.add_argument("--port", type=int)
    p.add_argument("--trusted-host")
    p = commands.add_parser("status", help="Show installation and runtime information")
    p.add_argument("--home")
    args = parser.parse_args(argv)
    try:
        if args.command == "install":
            install(args.home, args.repo, args.harness_tag, args.integration_tag, args.force)
        elif args.command == "start":
            return start(args.home, args.host, args.port, args.trusted_host)
        elif args.command == "status":
            home = Path(args.home).expanduser() if args.home else default_home()
            print("Harness:", "installed" if (home / "app" / "package.json").is_file() else "not installed")
            print("Home:", home)
            for name in ("node", "pnpm", "git"):
                print(name + ":", executable(name) or "not found")
    except Exception as exc:
        print(f"[OHAMLAB] ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
