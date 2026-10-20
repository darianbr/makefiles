import { existsSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';
import assert from 'node:assert/strict';

const cwd = new URL('.', import.meta.url).pathname;

function run(command, args) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: 'utf8',
    env: process.env,
  });

  if (result.status !== 0) {
    throw new Error(
      [
        `${command} ${args.join(' ')} failed with exit ${result.status}`,
        result.stdout,
        result.stderr,
      ].join('\n'),
    );
  }

  return result;
}

test('typescript and vitest module targets work in fixture', () => {
  run('make', ['npm', 'install']);
  run('make', ['typescript', 'test']);
  run('make', ['typescript', 'build']);
  run('make', ['vitest', 'test']);
  run('make', ['vitest', 'coverage']);

  assert.equal(existsSync(`${cwd}build/typescript/math.js`), true);
  assert.equal(existsSync(`${cwd}coverage/vitest/index.html`), true);
});
