以下では、各手順を AWS 公式ドキュメントに再照合し、誤りや不足を修正したものを示します。各ステップの内容は最新のドキュメントに基づき、コンソール操作と CLI 操作の両面から確認しています。

---

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

以上、公式ドキュメントに沿って再検証・修正を加えた最新手順です。ご確認ください。

[1]: https://docs.aws.amazon.com/ram/latest/userguide/working-with-shared-invitations.html?utm_source=chatgpt.com "Accepting and rejecting resource share invitations"
[2]: https://docs.aws.amazon.com/cli/latest/reference/ram/accept-resource-share-invitation.html?utm_source=chatgpt.com "accept-resource-share-invitation - AWS Documentation"
[3]: https://docs.aws.amazon.com/vpc/latest/tgw/create-vpc-attachment.html?utm_source=chatgpt.com "Create a VPC attachment using Amazon VPC Transit Gateways"
[4]: https://docs.aws.amazon.com/vpc/latest/tgw/acccept-tgw-attach.html?utm_source=chatgpt.com "Accept a shared attachment using Amazon VPC Transit Gateways"
[5]: https://docs.aws.amazon.com/vpc/latest/reachability/getting-started.html?utm_source=chatgpt.com "Getting started with Reachability Analyzer - Amazon Virtual Private ..."
[6]: https://docs.aws.amazon.com/ram/latest/userguide/getting-started-shared.html?utm_source=chatgpt.com "Using shared AWS resources - AWS Documentation"
[7]: https://docs.aws.amazon.com/cli/latest/reference/ec2/create-transit-gateway-vpc-attachment.html?utm_source=chatgpt.com "create-transit-gateway-vpc-attachment - AWS Documentation"
[8]: https://docs.aws.amazon.com/cli/latest/reference/ec2/accept-transit-gateway-vpc-attachment.html?utm_source=chatgpt.com "accept-transit-gateway-vpc-attachment - AWS Documentation"
[9]: https://docs.aws.amazon.com/vpc/latest/tgw/tgw-vpc-attachments.html?utm_source=chatgpt.com "Amazon VPC attachments in Amazon VPC Transit Gateways"
