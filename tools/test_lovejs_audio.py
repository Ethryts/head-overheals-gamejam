"""Regression coverage for the love.js 11.4.1 bulk audio source bug."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import build


class LovejsAudioTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("node"), "Node.js is needed to execute the audio glue")
    def test_vector_calls_receive_sources_and_patch_is_idempotent(self):
        # Same vector-call expression as the pinned runtime. Execute each state
        # transition against source objects with buffers, not just string-match.
        calls = "\n".join(
            f"AL.setSourceState(HEAP32[pSourceIds+i*4>>2],{state});"
            for state in (4114, 4115, 4116)
        )
        script = '''
const assert = require('node:assert/strict');
const src = {bufQueue: [1, 2]};
const AL = {currentCtx: {sources: {7: src}}, setSourceState(source, state) {
  assert.equal(source, src);
  assert.equal(source.bufQueue.length, 2);
  source.state = state;
}};
const HEAP32 = new Int32Array([0, 7]);
const pSourceIds = 4, i = 0;
''' + calls + '\nassert.equal(src.state, 4116);'
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "love.js"
            path.write_text(script)
            build.patch_lovejs_audio(path)
            patched = path.read_text()
            build.patch_lovejs_audio(path)
            self.assertEqual(path.read_text(), patched)
            subprocess.run([shutil.which("node"), str(path)], check=True, capture_output=True)

    def test_unaffected_runtime_is_preserved(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "love.js"
            original = "AL.setSourceState(src,4116);"
            path.write_text(original)
            build.patch_lovejs_audio(path)
            self.assertEqual(path.read_text(), original)
