#!/usr/bin/env node

import { copyFile, mkdir, readdir, rm, writeFile } from 'node:fs/promises'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const validationRoot = resolve(scriptDir, '..')
const outputRoot = resolve(validationRoot, 'generated/real-project-import')

const groups = [
  {
    title: 'WATCH Wearable ArkTS files',
    targetDir: 'watch-wearable/src',
    sources: [
      'huawei-watch-demo/src/MainPage.ets',
      'huawei-watch-demo/src/RouteModels.ets',
      'huawei-watch-demo/src/WearEngineBridge.ets',
      'huawei-watch-demo/README.md',
      'huawei-watch-demo/TODO.md',
      'huawei-watch-demo/app-manifest-notes.md'
    ]
  },
  {
    title: 'GT liteWearable files',
    targetDir: 'gt-lite/src',
    sources: [
      'huawei-gt-lite-demo/src/index.html',
      'huawei-gt-lite-demo/src/index.css',
      'huawei-gt-lite-demo/src/index.js',
      'huawei-gt-lite-demo/README.md',
      'huawei-gt-lite-demo/TODO.md',
      'huawei-gt-lite-demo/app-manifest-notes.md'
    ]
  },
  {
    title: 'HarmonyOS phone ArkTS sync files',
    targetDir: 'harmonyos-phone-sync/src',
    sources: [
      'huawei-phone-sync-demo/harmonyos-phone-sync-demo/src/RoutePayload.ets',
      'huawei-phone-sync-demo/harmonyos-phone-sync-demo/src/RouteTransport.ets',
      'huawei-phone-sync-demo/harmonyos-phone-sync-demo/src/LocalSimulationTransport.ets',
      'huawei-phone-sync-demo/harmonyos-phone-sync-demo/src/WearEngineRouteTransport.ets',
      'huawei-phone-sync-demo/harmonyos-phone-sync-demo/src/RouteFlowRunner.ets',
      'huawei-phone-sync-demo/harmonyos-phone-sync-demo/README.md',
      'huawei-phone-sync-demo/harmonyos-phone-sync-demo/TODO.md',
      'huawei-phone-sync-demo/harmonyos-phone-sync-demo/app-manifest-notes.md'
    ]
  },
  {
    title: 'Android phone Kotlin sync files',
    targetDir: 'android-phone-sync/src',
    sources: [
      'huawei-phone-sync-demo/android-phone-sync-demo/src/RoutePayload.kt',
      'huawei-phone-sync-demo/android-phone-sync-demo/src/RouteTransport.kt',
      'huawei-phone-sync-demo/android-phone-sync-demo/src/LocalSimulationTransport.kt',
      'huawei-phone-sync-demo/android-phone-sync-demo/src/WearEngineRouteTransport.kt',
      'huawei-phone-sync-demo/android-phone-sync-demo/src/RouteFlowRunner.kt',
      'huawei-phone-sync-demo/android-phone-sync-demo/README.md'
    ]
  },
  {
    title: 'Shared protocol samples',
    targetDir: 'shared',
    sources: [
      'shared/route-payload.sample.json',
      'shared/gt-navigation-payload.sample.json',
      'shared/route-ack.sample.json',
      'shared/watch-status.sample.json',
      'shared/validation-checklist.md',
      'shared/README.md'
    ]
  }
]

async function copySource(source, targetDir) {
  const sourcePath = resolve(validationRoot, source)
  const targetPath = resolve(outputRoot, targetDir, source.split('/').at(-1))
  await mkdir(dirname(targetPath), { recursive: true })
  await copyFile(sourcePath, targetPath)
  return {
    source,
    target: relative(validationRoot, targetPath)
  }
}

async function listGeneratedFiles(dir, prefix = '') {
  const entries = await readdir(dir, { withFileTypes: true })
  const files = []

  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
    const fullPath = join(dir, entry.name)
    const displayPath = join(prefix, entry.name)
    if (entry.isDirectory()) {
      files.push(...await listGeneratedFiles(fullPath, displayPath))
    } else {
      files.push(displayPath)
    }
  }

  return files
}

function renderManifest(copied) {
  const lines = [
    '# Huawei Real Project Import Bundle',
    '',
    `Generated at: ${new Date().toISOString()}`,
    '',
    'This directory is generated from `huawei-validation/` skeleton files.',
    'Create real DevEco Studio / Android Studio projects first, then copy the files from the matching subdirectory into the real project.',
    '',
    '## Import Order',
    '',
    '1. Create the WATCH `Wearable` project in DevEco Studio.',
    '2. Copy `watch-wearable/src/` files into the WATCH project source tree.',
    '3. Create the GT `liteWearable` or target GT-compatible project.',
    '4. Copy `gt-lite/src/` files into the GT project source tree.',
    '5. Create the HarmonyOS phone project and copy `harmonyos-phone-sync/src/`.',
    '6. Create the Android phone project and copy `android-phone-sync/src/`.',
    '7. Copy `shared/` into each project test resources or keep it as an external protocol fixture directory.',
    '',
    '## Copied Files',
    ''
  ]

  for (const group of copied) {
    lines.push(`### ${group.title}`, '')
    for (const item of group.files) {
      lines.push(`- \`${item.source}\` -> \`${item.target}\``)
    }
    lines.push('')
  }

  lines.push('## Validation', '')
  lines.push('After importing, keep this repository command passing:')
  lines.push('')
  lines.push('```sh')
  lines.push('node huawei-validation/scripts/run-local-flow-demo.mjs')
  lines.push('node huawei-validation/scripts/run-local-scenario-demo.mjs')
  lines.push('```')
  lines.push('')
  lines.push('The scenario demo writes `huawei-validation/generated/local-simulation/summary.json` and `events.jsonl`; keep those event shapes stable until Wear Engine true-device ACKs are captured.')
  lines.push('')

  return `${lines.join('\n')}\n`
}

async function main() {
  await rm(outputRoot, { recursive: true, force: true })
  await mkdir(outputRoot, { recursive: true })

  const copied = []
  for (const group of groups) {
    const files = []
    for (const source of group.sources) {
      files.push(await copySource(source, group.targetDir))
    }
    copied.push({ title: group.title, files })
  }

  await writeFile(resolve(outputRoot, 'MANIFEST.md'), renderManifest(copied), 'utf8')

  const generatedFiles = await listGeneratedFiles(outputRoot)
  console.log(`Generated ${generatedFiles.length} files in ${relative(process.cwd(), outputRoot)}`)
  for (const file of generatedFiles) {
    console.log(`- ${file}`)
  }
}

main().catch((error) => {
  console.error(`[FAIL] ${error.message}`)
  process.exit(1)
})
