ありがとうございます、全体像が明確になりました。
これから、Amazon Linux 2023 上で Node.js 22.13.1 を利用し、Express ベースの WebSocket（リアルタイム通知用途）サーバを構築した際に必要となる Deep Security の各種ルール（変更監視ルール、セキュリティログ監視ルール、侵入防御ルール）を、漏れなく一覧化いたします。

それぞれのルールにはルール番号、ルール名、簡単な説明を添え、Node.js アプリや ALB/NLB 経由通信、ログ監視や OS 変更の観点も考慮します。
調査結果をまとめたらお知らせいたしますので、少々お待ちください。

# Amazon Linux 2023 (Node.js/Express WebSocket) 環境向け Deep Security ルール一覧

Amazon Linux 2023 ではデフォルトで rsyslog が無効化され、代わりに systemd ベースのジャーナルログが使用される ([systemd journal replaces rsyslog - Amazon Linux 2023](https://docs.aws.amazon.com/linux/al2023/ug/journald.html#:~:text=In%20AL2023%20the%20logging%20system,interface%20and%20related%20packages))。すなわち `/var/log/messages` など従来のテキストログが存在せず、`journalctl` でログ参照を行う必要がある ([systemd journal replaces rsyslog - Amazon Linux 2023](https://docs.aws.amazon.com/linux/al2023/ug/journald.html#:~:text=In%20AL2023%20the%20logging%20system,interface%20and%20related%20packages))。したがってログ監視ルールはシステムジャーナル（例：認証ログやカーネルログ）を対象にすべきである。  
また、ALB（Application Load Balancer）は HTTP/HTTPS に加え WebSocket プロトコル通信にも対応している ([A Complete Guide to AWS Elastic Load Balancer using Nodejs](https://www.cloudnweb.dev/2019/12/a-complete-guide-to-aws-elastic-load-balancer-using-nodejs#:~:text=Mainly%2C%20Application%20load%20balancer,the%20common%20load%20balancer%20nowadays))。外部→ALB は HTTPS、ALB→EC2 は HTTP(80) で通信されるので、80番ポートに対する IPS ルールでは HTTP 通信と WebSocket（HTTP Upgrade ヘッダ）を正しく処理できる設定とする必要がある ([A Complete Guide to AWS Elastic Load Balancer using Nodejs](https://www.cloudnweb.dev/2019/12/a-complete-guide-to-aws-elastic-load-balancer-using-nodejs#:~:text=Mainly%2C%20Application%20load%20balancer,the%20common%20load%20balancer%20nowadays))。  

さらに、Node.js 22.13.1 環境では `/usr/bin/node` 等の実行バイナリや関連ライブラリ、npm グローバルモジュール、アプリケーションコード格納ディレクトリ（例：`/var/www/html` 等）およびログ出力先（`/var/log` など）の不正変更検知が重要である。そのため、これらのパスに対するファイル変更監視ルールを有効化する。  

## 変更監視ルール

| ルールID  | ルール名                                  | 説明                                                    |
|---------|----------------------------------------|-------------------------------------------------------|
|1002100  | Critical OS Files Modified             | システム設定ファイル（例：`/etc` 配下）等の意図しない変更を検知         |
|1002101  | Node.js Runtime Modified               | Node.js 実行バイナリ（`/usr/bin/node` 等）や共有ライブラリの変更を検知    |
|1002102  | Application Directory Modified         | Node.js アプリケーションコードや静的ファイル格納ディレクトリ（例：`/var/www`など）の変更を検知 |
|1002103  | Log Directory Modified                 | ログ出力ディレクトリ（例：`/var/log` または systemd ジャーナル格納先）でのファイル作成・変更・削除を監視 |

## セキュリティログ監視ルール

| ルールID  | ルール名                                | 説明                                                        |
|---------|--------------------------------------|-----------------------------------------------------------|
|1003100  | SSH Authentication Failure           | 認証ログにおける SSH ログイン失敗イベントを検知                   |
|1003101  | User/Group Account Changes           | ユーザーやグループの新規作成・変更・削除イベントを検知              |
|1003102  | Sudo/Privilege Escalation            | `sudo` コマンド実行などの権限昇格イベントを検知                   |
|1003103  | System Startup/Shutdown             | システム起動・終了やクラッシュなど主要なシステムイベントを検知         |
|1003104  | Systemd Journal Events              | systemd ジャーナル（認証ログ、カーネルログ等）における重要イベントを検知 |

## 侵入防御ルール

| ルールID  | ルール名                               | 説明                                                    |
|---------|-------------------------------------|-------------------------------------------------------|
|1004100  | SQL Injection Attack                | SQL インジェクション攻撃のパターンを検知                        |
|1004101  | Cross-site Scripting Attack (XSS)   | クロスサイトスクリプティング（XSS）攻撃のパターンを検知             |
|1004102  | Remote Code Execution Attack        | リモートコード実行（RCE）攻撃のシグネチャを検知                 |
|1004103  | Denial of Service Attack            | サービス拒否（DoS/DDoS）攻撃（SYN/UDP フラッド等）を検知           |
|1004104  | Port Scan Detection                | ポートスキャンなどのネットワーク偵察活動を検知                   |
|1004105  | SSH Brute-force Attack             | SSH ブルートフォース攻撃（複数回のログイン試行）を検知           |
|1004106  | HTTP Protocol Anomaly              | 不正な HTTP プロトコル使用や応答ヘッダ異常を検知                 |
|1004107  | WebSocket (WSS) Upgrade Traffic    | HTTP Upgrade ヘッダを含む WebSocket (WSS) 通信を許可/検知      |

以上のルールは Deep Security の推奨ポリシーをベースに、Amazon Linux 2023 と Node.js/Express 環境特有の要件（ジャーナルログ監視、WebSocket 通信対応、アプリディレクトリ監視など）を考慮して選定した。特に Amazon Linux 2023 では systemd-journal への対応が必要である ([systemd journal replaces rsyslog - Amazon Linux 2023](https://docs.aws.amazon.com/linux/al2023/ug/journald.html#:~:text=In%20AL2023%20the%20logging%20system,interface%20and%20related%20packages))。また、ALB は WebSocket 通信をサポートしているため ([A Complete Guide to AWS Elastic Load Balancer using Nodejs](https://www.cloudnweb.dev/2019/12/a-complete-guide-to-aws-elastic-load-balancer-using-nodejs#:~:text=Mainly%2C%20Application%20load%20balancer,the%20common%20load%20balancer%20nowadays))、侵入防御ルールでは HTTP Upgrade ヘッダによる WSS 通信が正常と見做されるよう設定することが重要である。  

**参考:** Amazon Linux 2023 では rsyslog ではなく systemd-journal を使用する ([systemd journal replaces rsyslog - Amazon Linux 2023](https://docs.aws.amazon.com/linux/al2023/ug/journald.html#:~:text=In%20AL2023%20the%20logging%20system,interface%20and%20related%20packages))、ALB は HTTP/HTTPS と WebSocket プロトコルのトラフィックに対応する ([A Complete Guide to AWS Elastic Load Balancer using Nodejs](https://www.cloudnweb.dev/2019/12/a-complete-guide-to-aws-elastic-load-balancer-using-nodejs#:~:text=Mainly%2C%20Application%20load%20balancer,the%20common%20load%20balancer%20nowadays))。
