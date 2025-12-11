# Firebase Emulator Scripts

このディレクトリには、Firebase Emulatorを使用してテストを実行するためのスクリプトが含まれています。

## run_with_emulator.sh

Firebase EmulatorとともにSwiftのビルドとテストを実行するための統合スクリプトです。

### 要件

- Java 21以上（Firebase CLI 15.0.0以降で必要）

### 使い方

```bash
# 基本的な使い方
cd firebase
./run_with_emulator.sh "swift build && swift test"

# ビルドのみ
./run_with_emulator.sh "swift build"

# テストのみ
./run_with_emulator.sh "swift test"

# カスタムコマンド
./run_with_emulator.sh "your custom command"
```

### 機能

- Firebase CLIの自動インストール（未インストールの場合）
- Firestore EmulatorとStorage Emulatorの自動セットアップ
- エミュレータの起動・コマンド実行・停止を自動管理
- エミュレータデータの永続化（`./firebase/data`ディレクトリ）

### メリット

- **シンプル**: 1つのコマンドで全てを管理
- **信頼性**: エミュレータのクリーンアップが自動化
- **再現性**: データのインポート/エクスポート機能
- **ローカル開発**: CI/CDと同じ環境でローカルテスト可能

## レガシースクリプト

以下のスクリプトは後方互換性のために残されていますが、新しいコードでは`run_with_emulator.sh`の使用を推奨します。

- `emulator_setup.sh`: エミュレータの手動起動（バックグラウンド）
- `wait_firebase_emulator_setup.sh`: エミュレータ起動の待機

## GitHub Actions

GitHub Actionsワークフローでも同じスクリプトが使用されており、ローカル環境とCI環境で同じテスト実行方法を保証します。

参照: [.github/workflows/sources.yml](../.github/workflows/sources.yml)
