## 要点まとめ

* **共有承諾**（RAM）では、リージョン選択や IAM 権限要件を明示し、コンソール・CLI 両方の最新手順を盛り込みました([AWS ドキュメント][1])([AWS ドキュメント][2])。
* **VPC アタッチ作成**では、タグ付けオプションや DNS/IPv6/Appliance モード設定など、ドキュメント通りの全設定項目を追加しました([AWS ドキュメント][3])。
* **アタッチ承諾**では、クロスアカウント共有時の「手動承諾設定」の文言を整理し、コンソール／CLI 両方を正確に反映しました([AWS ドキュメント][4])。
* **疎通確認**では、ルート設定、セキュリティ設定、EC2 からの ping、Reachability Analyzer 活用の全手順を公式手順に沿って補強しました([AWS ドキュメント][5])。

---

## 2. TGW の共有を承諾する

### 2-1. 前提事項

* アカウントA 側で AWS RAM を用い、Transit Gateway（TGW）がアカウントB に対して共有済みであること([AWS ドキュメント][6])。
* アカウントB で以下の IAM 権限が必要：

  * `ram:GetResourceShareInvitations`
  * `ram:AcceptResourceShareInvitation`

### 2-2. コンソール操作手順

1. AWS Management Console にアカウントB でログインする。
2. リージョンが正しいか（資源作成したリージョン、グローバル資源の場合は us-east-1）確認する。
3. サービス検索で「**RAM**」を選択し、左ペインの「**Shared with me**」をクリック([AWS ドキュメント][1])。
4. 一覧から該当するリソースシェア（状態 `Pending`）を選択し、上部の「**Accept resource share**」を押下。
5. 確認ダイアログで「**Accept**」をクリックし、ステータスが `Active` に変わることを確認。

> **参照**：Accepting and rejecting resource share invitations (AWS RAM User Guide)([AWS ドキュメント][1])

### 2-3. AWS CLI 操作手順

1. 保留中の招待一覧を取得：

   ```bash
   aws ram get-resource-share-invitations \
     --resource-owner OTHER-ACCOUNTS \
     --query 'resourceShareInvitations[?status==`PENDING`].[resourceShareInvitationArn]' \
     --output text
   ```
2. 招待 ARN を変数に入れ、承諾：

   ```bash
   INVITE_ARN=<取得したリソースシェア招待ARN>
   aws ram accept-resource-share-invitation \
     --resource-share-invitation-arn $INVITE_ARN
   ```

> **参照**：accept-resource-share-invitation (AWS CLI Reference)([AWS ドキュメント][2])

---

## 3. TGW アタッチメントを作成する

### 3-1. 前提事項

* アカウントB で共有済み TGW が表示されていること（手順2完了後）([AWS ドキュメント][3])。
* アタッチ先 VPC に少なくとも各 AZ で 1 つずつサブネットが存在すること。

### 3-2. コンソール操作手順

1. AWS Management Console で「**VPC**」を開き、左ペインの「**Transit Gateway Attachments**」をクリック([AWS ドキュメント][3])。
2. 「**Create transit gateway attachment**」を選択。
3. 各項目を設定：

   * **Name tag**：任意
   * **Transit gateway ID**：共有された TGW を選択
   * **Attachment type**：`VPC`
   * **DNS Support**，**IPv6 Support**，**Appliance mode support**，**Security Group Referencing**：必要に応じて設定
   * **VPC ID**：アタッチ先 VPC
   * **Subnet IDs**：各 AZ から 1 つずつ選択
4. 「**Create transit gateway attachment**」を押下し、状態が `pendingAcceptance` または `available` になることを確認。

> **参照**：Create a VPC attachment using the console (Transit Gateway Developer Guide)([AWS ドキュメント][3])

### 3-3. AWS CLI 操作手順

```bash
aws ec2 create-transit-gateway-vpc-attachment \
  --transit-gateway-id tgw-0123456789abcdef0 \
  --vpc-id vpc-0abcdef1234567890 \
  --subnet-ids subnet-aaa111bbb subnet-ccc222ddd \
  --options ApplianceModeSupport=enable,DnsSupport=enable,SecurityGroupReferencingSupport=enable
```

> **参照**：create-transit-gateway-vpc-attachment (AWS CLI Reference)([AWS ドキュメント][7])

---

## 4. TGW アタッチメントを承諾する

> **注意**：アタッチ元アカウントA にて「Auto accept shared attachments」が有効化されていない場合のみ必要。

### 4-1. コンソール操作手順

1. アカウントA でコンソールにログインし、「**VPC**」→「**Transit Gateway Attachments**」を開く。
2. 状態が `pendingAcceptance` のアタッチメントを選択。
3. 「**Actions**」→「**Accept transit gateway attachment**」をクリック([AWS ドキュメント][4])。
4. 確認ダイアログで「**Accept**」を押下し、状態が `available` になることを確認。

### 4-2. AWS CLI 操作手順

```bash
aws ec2 accept-transit-gateway-vpc-attachment \
  --transit-gateway-attachment-id tgw-attach-0abcdef1234567890
```

> **参照**：accept-transit-gateway-vpc-attachment (AWS CLI Reference)([AWS ドキュメント][8])

---

## 5. 疎通確認手順

### 5-1. ルートテーブル設定

1. **TGW ルートテーブル**（Transit Gateway Route Table）に、相手 VPC の CIDR へのルートを追加。
2. **VPC サブネットルートテーブル**に、ターゲットとして該当の TGW アタッチメントを追加([AWS ドキュメント][9])。

### 5-2. ネットワーク ACL／セキュリティグループ確認

* 相手 VPC からの **Inbound／Outbound** トラフィックが ACL および SG で許可されていることを確認。

### 5-3. EC2 インスタンスでの直接疎通テスト

1. VPC A 上の EC2（例：`10.0.1.10`）と VPC B 上の EC2（例：`10.1.1.10`）を用意。
2. EC2 A から EC2 B へ `ping -c 4 10.1.1.10` を実行し応答を確認。
3. EC2 B から EC2 A へ `ping -c 4 10.0.1.10` を実行し応答を確認。

### 5-4. VPC Reachability Analyzer 利用

1. AWS コンソールで「**VPC Reachability Analyzer**」を開く。
2. **Source** に送信元 ENI/IP、**Destination** に宛先 ENI/IP を指定し「Create and analyze path」。
3. 結果が「Reachable」であり、ホップ詳細が正しいことを確認([AWS ドキュメント][5])。

> **参照**：Getting started with Reachability Analyzer (VPC Reachability Analyzer User Guide)([AWS ドキュメント][5])

---

[1]: https://docs.aws.amazon.com/ram/latest/userguide/working-with-shared-invitations.html?utm_source=chatgpt.com "Accepting and rejecting resource share invitations"
[2]: https://docs.aws.amazon.com/cli/latest/reference/ram/accept-resource-share-invitation.html?utm_source=chatgpt.com "accept-resource-share-invitation - AWS Documentation"
[3]: https://docs.aws.amazon.com/vpc/latest/tgw/create-vpc-attachment.html?utm_source=chatgpt.com "Create a VPC attachment using Amazon VPC Transit Gateways"
[4]: https://docs.aws.amazon.com/vpc/latest/tgw/acccept-tgw-attach.html?utm_source=chatgpt.com "Accept a shared attachment using Amazon VPC Transit Gateways"
[5]: https://docs.aws.amazon.com/vpc/latest/reachability/getting-started.html?utm_source=chatgpt.com "Getting started with Reachability Analyzer - Amazon Virtual Private ..."
[6]: https://docs.aws.amazon.com/ram/latest/userguide/getting-started-shared.html?utm_source=chatgpt.com "Using shared AWS resources - AWS Documentation"
[7]: https://docs.aws.amazon.com/cli/latest/reference/ec2/create-transit-gateway-vpc-attachment.html?utm_source=chatgpt.com "create-transit-gateway-vpc-attachment - AWS Documentation"
[8]: https://docs.aws.amazon.com/cli/latest/reference/ec2/accept-transit-gateway-vpc-attachment.html?utm_source=chatgpt.com "accept-transit-gateway-vpc-attachment - AWS Documentation"
[9]: https://docs.aws.amazon.com/vpc/latest/tgw/tgw-vpc-attachments.html?utm_source=chatgpt.com "Amazon VPC attachments in Amazon VPC Transit Gateways"

---

---

## ベストプラクティス

### 1. 件名は簡潔かつ具体的に

* 「サービス名＋問題／確認内容＋影響範囲」を含めると、サポート側が内容を素早く把握できます([AWS ドキュメント][1])。

### 2. サポートケースの種別と重要度を明示

* 「Technical」など適切なケース種別を選択し、影響度に応じた Severity（例：`general guidance`／`system impaired`）を設定します([AWS ドキュメント][2])。
* 重要度が高い場合のみ、上位レベルを選択するのが良いとされています([AWS ドキュメント][2])。

### 3. 環境情報の詳細記載

* AWS アカウント ID、リージョン、利用中の AWS CLI／SDK バージョンを明記します([AWS ドキュメント][2])。
* 該当リソースの ARN や ID（例：`tgw-0123456789abcdef0`）を含めると、オペレーションがスムーズになります([Repost][3])。

### 4. 再現手順と期待動作の提示

* 手順をステップごとに番号付きで示し、実際の出力例やログを添付すると、問題切り分けが容易になります([Repost][4])。

### 5. 事前調査結果と参照ドキュメント

* AWS ドキュメントへのリンク（例：RAM／TGW／Reachability Analyzer の該当ページ）を示すと、参照すべき箇所がひと目でわかります([AWS ドキュメント][5])。

### 6. 添付ファイルの活用

* CLI 実行ログや CloudTrail ログ、構成ファイル（Terraform／CloudFormation）を ZIP 化して添付します([AWS ドキュメント][6])。

### 7. 連絡方法とタイムゾーン

* メール／チャット／電話のいずれを希望するか明記し、業務時間帯やタイムゾーンを併記すると良いでしょう([AWS ドキュメント][1])。

### 8. 期待する回答期限

* ビジネス影響度に応じて「◯月◯日までにご回答いただけますと幸いです」など、回答期限を示します。AWS のサポート応答時間はプランによって異なります（例：General 24 時間以内）([AWS ドキュメント][7])。

---

## 問い合わせメール例

```plaintext
件名: 【Technical/General Guidance】TGW 共有承諾～アタッチ手順の公式ドキュメント準拠確認のお願い (Account B)

AWS サポート御中

お世話になっております。  
XXX株式会社　クラウド基盤部のYYYと申します。  

現在、アカウントB 側において、アカウントA から RAM 経由で共有された Transit Gateway (tgw-0123456789abcdef0) を下記手順で承諾・アタッチし、疎通確認を行いましたが、手順が最新の AWS 公式ドキュメントに沿っているか、また設定に抜け漏れや誤りがないかをご確認いただきたく存じます。

――――――――――――  
1. 共有リソースの承諾  
   • RAM > Shared with me > Accept resource share (Pending → Active)  
   • CLI: `aws ram accept-resource-share-invitation --resource-share-invitation-arn <ARN>`  

2. VPC アタッチメントの作成  
   • VPC > Transit Gateway Attachments > Create  
   • DNS/IPv6/Appliance モード設定を有効化  
   • CLI: `aws ec2 create-transit-gateway-vpc-attachment --transit-gateway-id tgw-... --vpc-id vpc-... --subnet-ids subnet-... --options ApplianceModeSupport=enable,DnsSupport=enable`  

3. アタッチの承諾（アカウントA 側）  
   • VPC > Transit Gateway Attachments (pendingAcceptance → available)  
   • CLI: `aws ec2 accept-transit-gateway-vpc-attachment --transit-gateway-attachment-id tgw-attach-...`  

4. 疎通確認  
   • TGW/サブネットルートテーブルへの相手 VPC CIDR 追加  
   • EC2 インスタンス間の ping 確認  
   • Reachability Analyzer で “Reachable” 確認  

※詳細なログやスクリーンショットは添付ファイルをご参照ください。  
――――――――――――  

【環境情報】  
- アカウント ID：123456789012  
- リージョン：ap-northeast-1  
- AWS CLI バージョン：2.11.5  
- Terraform バージョン：1.4.6  

お手数をおかけしますが、上記手順に誤りや抜けがないかご確認のほど、よろしくお願いいたします。  
回答はメール（YYY@company.co.jp）またはチャットでお送りいただけますと幸いです。

以上、何卒よろしくお願いいたします。

――――  
YYY  
XXX株式会社 クラウド基盤部  
Tel: 03-1234-5678  
Email: YYY@company.co.jp  
```

---

[1]: https://docs.aws.amazon.com/awssupport/latest/user/case-example.html?utm_source=chatgpt.com "Example: Create a support case for account and billing - AWS Support"
[2]: https://docs.aws.amazon.com/awssupport/latest/user/case-management.html?utm_source=chatgpt.com "Creating support cases and case management - AWS Documentation"
[3]: https://repost.aws/knowledge-center/information-support-case?utm_source=chatgpt.com "File an AWS Support case with required information | AWS re:Post"
[4]: https://repost.aws/articles/ARF5I10rw-R7uXnfC2MRvz4Q/following-best-practices-to-create-and-manage-your-aws-support-cases?utm_source=chatgpt.com "Following best practices to create and manage your AWS Support ..."
[5]: https://docs.aws.amazon.com/awssupport/latest/APIReference/API_CreateCase.html?utm_source=chatgpt.com "CreateCase - AWS Support"
[6]: https://docs.aws.amazon.com/awssupport/latest/user/monitoring-your-case.html?utm_source=chatgpt.com "Updating, resolving, and reopening your case - AWS Support"
[7]: https://docs.aws.amazon.com/awssupport/latest/user/getting-started.html?utm_source=chatgpt.com "Getting started with AWS Support"
