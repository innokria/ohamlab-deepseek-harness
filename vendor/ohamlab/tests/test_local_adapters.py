import importlib.util
from pathlib import Path
from unittest.mock import patch, Mock

ROOT = Path(__file__).resolve().parents[1] / "adapters"

def load(filename):
    spec = importlib.util.spec_from_file_location("adapter_under_test", ROOT / filename)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

def test_search_invokes_cli_without_shell():
    mod = load("local_search_adapter.py")
    with patch("shutil.which", return_value="/usr/bin/ohamlab"), patch("subprocess.run", return_value=Mock(returncode=0, stdout="result", stderr="")) as run:
        assert mod.ohamlab_search("python") == "result"
        assert run.call_args.args[0] == ["/usr/bin/ohamlab", "search", "python", "--max-results", "5"]

def test_lab_create_agent_cli(tmp_path):
    mod = load("local_agent_lab_adapter.py")
    mod.DATA_DIR = tmp_path
    with patch("shutil.which", return_value="/usr/bin/ohamlab-lab"), patch("subprocess.run", return_value=Mock(returncode=0, stdout='{"id":"a1"}', stderr="")) as run:
        assert mod.create_agent("Research Agent")["id"] == "a1"
        assert "create-agent" in run.call_args.args[0]
