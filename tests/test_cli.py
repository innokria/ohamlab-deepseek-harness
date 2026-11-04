from pathlib import Path
from unittest.mock import patch
from ohamlab_harness.cli import main
from ohamlab_harness.installer import install_skills, InstallError
from ohamlab_harness.runtime import start
import pytest

def test_version(capsys):
    with pytest.raises(SystemExit) as ex:
        main(["--version"])
    assert ex.value.code == 0
    assert "0.1.0b1" in capsys.readouterr().out

def test_start_requires_install(tmp_path):
    with pytest.raises(InstallError,match="not installed"):
        start(tmp_path)

def test_install_skills(tmp_path):
    src=tmp_path/"src"
    for name in ("web-search","agent-lab","research-workflow"):
        (src/name).mkdir(parents=True)
        (src/name/"SKILL.md").write_text(name)
        (src/name/"reference.txt").write_text("extra")
    dest=tmp_path/"dst"
    install_skills(src,dest)
    assert (dest/"agent-lab"/"reference.txt").read_text()=="extra"

def test_start_runs_command(tmp_path):
    (tmp_path/"app").mkdir()
    (tmp_path/"app"/"package.json").write_text("{}")
    (tmp_path/"data"/"skills"/"web-search").mkdir(parents=True)
    (tmp_path/"data"/"skills"/"web-search"/"SKILL.md").write_text("ok")
    with patch("ohamlab_harness.runtime.subprocess.call",return_value=0) as call:
        assert start(tmp_path,command="pnpm dsh web")==0
        assert call.call_args.args[0]==["pnpm","dsh","web"]
        assert call.call_args.kwargs["env"]["DSH_HOME"]==str(tmp_path/"data")
