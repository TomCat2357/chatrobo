# AzureChatMachine2に関するReadMe

## 概要
OPENAIのAPIを用いて、GPTとチャットするためのプロジェクトです。Dockerを使用してApacheサーバー、Streamlitアプリケーション、およびRedisデータベースを組み合わせて、ウェブアプリケーション基盤を構築します。

## 特徴
- Apache, Streamlit, Redisそれぞれをコンテナ化し、組み合わせたアプリケーション構成
- 安全な通信のためのSSL証明書生成スクリプト
- 初期セットアップを簡単にするスクリプト

![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white)
![Apache](https://img.shields.io/badge/Apache-D22128?logo=apache&logoColor=white)
![Redis](https://img.shields.io/badge/Redis-DC382D?logo=redis&logoColor=white)
![Streamlit](https://img.shields.io/badge/Streamlit-FF4B4B?logo=streamlit&logoColor=white)

## Dockerコンテナ構成
- **apache**: Apacheサーバーをホストするコンテナ
- **streamlit**: Streamlitアプリケーションをホストするコンテナ
- **redis_6379**: Redisデータベースをホストするコンテナ

## Dockerファイル
- **docker/apache_docker/Dockerfile**: Apacheコンテナの構成ファイル
- **docker/streamlit_docker/Dockerfile**: Streamlitコンテナの構成ファイル
- **docker/redis_conf/6379/redis.conf**: Redis設定ファイル

## サービス構成
- **apache**: Apacheサーバーを実行し、ポート443と80を公開。それぞれHOSTのポート443と80に接続しています。
- **streamlit**: Streamlitアプリケーションを実行し、ポート8501を公開
- **redis_6379**: Redisデータベースを実行し、ポート6379を公開

## その他
- **init_setup_20231223.sh**: 最初にDocker関連のパッケージをインストールするスクリプト。
- **key_gen.sh**: SSL証明書とキーを生成するスクリプト。基本的に使わない
- **docker/data/redis_6379/dump.rdb**: redisサーバーのスナップショット 

## セットアップ方法
1. このリポジトリをクローンします
```bash
git clone https://github.com/tomo2357/AzureChatMachine2.git
```

2. リポジトリ内に移動します。
```bash
cd AzureChatMachine2
```

3. `init_setup_20231223.sh`を実行して、必要なDocker関連のパッケージをインストールします。また、秘密鍵やlogout時のテナントID、クライアントID等を入力する.env_secretファイルも作成されます。
```bash
./init_setup_20231223.sh
```

4.`.env_secret`を編集して、必要な情報を入力してください。
```bash
sudo vim docker/apache_docker/.env_secret
```

```.env_secretの中身
# .env_secret
# これは秘密鍵や固有のID等を保存するためのファイルです。
# ".env_secret"にファイル名を変更し、内容も正しいものに書き換えてください。
EMAIL=LetsEncryptから連絡するためのあなたのメールアドレス 例　abc.edf@gmail.com
DOMAINNAME=あなたのドメイン名　例 www.hogehoge.com
TENANT_ID=Azureでアプリを登録したテナントID
CLIENT_ID=Azureでアプリを登録したクライアントID
CLIENT_SECRET=Azureでアプリを登録したクライアントのシークレット
PASSPHRASE=Apache2で暗号化だかなんだかに使うパスフレーズ
```

5. Dockerコンテナをビルドして実行します。
```bash
docker-compose up --build -d
``` 
