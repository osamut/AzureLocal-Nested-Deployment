# Azure Local 23H2 Nested Hyper-V での展開方法

## 0. 本手順が想定しているネットワーク構成図

![image](https://github.com/osamut/AzureLocal-Nested-Deployment/blob/main/Nested-AzureLocal%E7%B0%A1%E6%98%93%E6%A7%8B%E6%88%90%E5%9B%B3.png))

### 現在 ”Azure Stack HCI” から ”Azure Local" へのブランド変更中のため、画面によって表記が変わることがあるが、同じものとして処理を続行してください
- Azure local 各ノード用のVMには vCPU 16、メモリ 32GB、起動ディスク200GB (可変ディスク)、ストレージ用ディスク 100GBx6 (可変ディスク) を割り当てている
- パラメーター化はしていないが、変更が可能なので環境に合わせてスクリプト内の数値を変更してください

## 1. ステップ０： Hyper-V 環境の準備

- Hyper-V マシンを用意
- 仮想スイッチを作成
- 仮想スイッチをNATに設定　https://learn.microsoft.com/ja-jp/virtualization/hyper-v-on-windows/user-guide/setup-nat-network
- Active Directory ドメインコントローラー用の仮想マシンを１台作成し、AD＋DNS環境を構築
- AD に Azure Local 作成用の環境を事前設定する　https://learn.microsoft.com/ja-jp/azure/azure-local/deploy/deployment-prep-active-directory
- AzureLocal-NestedVM作成テンプレート.ps1 をダウンロード
- ダウンロードしたファイルをノード数分コピーしておくと作業効率が上がる
- Hyper-V マシンにて PowerShell ISE を管理者モードで起動し、作成テンプレートを開く
　　※ISEをノード数分起動してそれぞれでファイルを開くと Azure Local ノード作成も並行処理が可能

## 2. ステップ１： 疑似的な Azure local ノード (仮想マシン) の作成
	
- 作成テンプレートのステップ１を利用
- ノード名や準備段階でNAT設定したHyper-V仮想スイッチ名、Azure Local ISOイメージのパス、仮想マシンを配置するフォルダー名などをパラメーターを記入
- 「### ステップ１開始」から「### ステップ１終了」までの行を選択し、[選択項目を実行(F8)]をクリック
	- 仮想マシンの作成、設定が自動で行われ、Hyper-Vのコンソールが立ち上がる
	- コンソール内では、仮想マシンが自動起動し、ISOからブートするための画面になるのでEnterなどを押下し、Azure Local OSのインストールを実行
	- OSは１つだけ違うサイズのディスク(一番上に表示される)にインストール
- インストール完了後、administrator のパスワードを入力
	- 画面上で Sconfig が起動するが、(現時点では) 数分以内に自動で再起動が始まるため、再起動が完了するまで待つとよい
	- もし数分経って再起動しない場合は次のステップに進む 
    
## 3. ステップ２：　Azure Local ノードのネットワーク設定

- 作成テンプレートのステップ２を利用
- 管理用NICのIPアドレス、デフォルトゲートウェイ、DNSサーバーIPアドレス、administrator のパスワードなどのパラメーターを記入
	- パスワードを都度入力したい場合はスクリプトを調整すること 
- 「### ステップ２開始」から「### ステップ２終了」までの行を選択し、[選択項目を実行(F8)]をクリック
	- ネットワーク設定が自動で行われ、仮想マシンが自動で再起動
	- 再起動したら次のステップに進む 

## 4. ステップ３： 各ノードを Azure Arc へ登録

- Azure サブスクリプションの準備が整っていることが前提
	- リソースグループの作成
	- RBAC 権限設定 https://learn.microsoft.com/ja-jp/azure/azure-local/deploy/deployment-arc-register-server-permissions?tabs=powershell

- 作成テンプレートのステップ３を利用
- Azure サブスクリプションIDなどの各パラメーターをスクリプトに記入
- Hyper-Vの仮想マシンコンソールにAdministratorのパスワードを入力し、ログオン ~Sconfig起動
-「Enter number to select an option:」に 15 と入力して PowerShell の画面に移動
-「### ステップ３開始」から「### ステップ３終了」までの行をコピーし、仮想マシンコンソールの PowerShell 画面に張り付け
	- 途中 認証用のコードが表示されるのでコードをコピー
	- ブラウザーが利用可能な手元のマシンなどで https://microsoft.com/devicelogin にアクセスし、コードを貼り付けし、RBAC設定を行ったIDで認証を実施
	- そのまま処理が進み、各ノードが Azure Arc に登録される
- Azure Portal の Azure Arc 管理画面で登録されたノードをクリック
- [設定]の下の[拡張機能]をクリックし、4つの拡張モジュールの作成が完了するのを待つ　　(しばらくすると5つ目も作成されているが気にしない)
- すべてのノードで拡張機能の作成が完了したら次のステップへ
	
## 5. ステップ４：Azure ポータルでの事前作業　※Nested 関係なし
	
- Azure ポータル(https://portal.azure.com) にログオン
- Azure ポータルを英語に変更
	- 不要なトラブルを回避するため
 	- (本手順書作成時は日本語ポータルだと仮想スイッチ名の文字化けなどに遭遇)
- Azure Local に関連するオブジェクトを登録するリソースグループを新規作成
	- (リソースグループに対して各オブジェクトが作成される)
	- 2024年5月4日時点で Japan East での作業が可能になっている
	- リソースグループに対して、Azure 側で作業をするアカウントに以下の管理権限を付与
 		- Azure Connected Machine Onboarding
   		- Azure Connected Machine Resource Administrator
	- サブスクリプションに以下のリソースプロバイダーが登録されていることを確認し、登録されていなければ登録する		
		- Microsoft.HybridCompute
  		- Microsoft.GuestConfiguration
		- Microsoft.HybridConnectivity
  		- Microsoft.AzureStackHCI

## 6. ステップ５：　Azure Local クラスター展開　※ Nested 関係なし
	
### 事前設定
- Azure ポータルが英語であることを確認  ・・・不要なトラブルを回避するため
- サブスクリプションに対し、Azure 側の作業をするアカウントに以下の管理権限を付与
	- Azure Stack HCI Administrator
  	- Reader
 - リソースグループに対し、Azure 側の作業をするアカウントに以下の管理権限を付与
 	- Key Vault Data Access Administrator
  	- Key Vault Secrets Officer　　　      (日本語ポータル作業時は ”キーコンテナーシークレット責任者” を探す)
   	- Key Vault Contributor
   	- Storage Account Contributor
### クラスター構築作業
-  Azure ポータルの [Azure Arc] - [Azure Stack HCI] 管理画面にて、[All Clusters (PREVIEW)] を選択
	-  PREVIEW ではない画面にしたい場合は、画面内の [Old Experience] をクリックすると GA 済みの画面が表示される
#### 1. [+Create] メニューから [Azure Stack HCI Cluster] を選択
#### 2. Basics タブ
- 2-1: 展開に利用する [サブスクリプション] と [リソースグループ] を選択
	- リソースグループが違うと画面一番下に Arc に登録したサーバー一覧が表示されないので注意
- 2-2: [Cluster name] を入力
- 2-3: Region はサポートしているリージョンを入力　※ Japan East で OK
- 2-4: Key vault name では [Create a new key vault] をクリックし、右に出てくる画面で [Create] をクリック
	- 権限付与のリンクが表示されたらクリック 
	- 繰り返し同じ作業をした場合は既存の Key Vault を削除するか、Key Vault name を変更する事で対応
	- Key Vault は削除しても削除済みリストに残るので、削除済みリストからさらに削除する必要がある
 - 2-5: リソースグループ内の Azuer Stack HCI ノードの一覧が表示されるので、クラスターに参加させるノードにチェックを入れし、[Validate selected servers] をクリック
 	- このタイミングでホストのNIC情報を取得するため不要なNICの削除などはこの前に行っておくこと
 - 2-6: Validate が完了したら [Next: Configuration] をクリック
#### 3. Configuration タブ
 - [New configuration] が選択されていることを確認し [Next: Networking] をクリック
 	- テンプレートが用意できている場合はテンプレートを利用
#### 4.  Networking タブ
- ※ ここは実際の環境に合わせて設定をする必要がある
- ※ 以下は NIC4 枚の環境にて、管理＆VM 用ネットワークに NIC1 と NIC2 を、ストレージ用に NIC3 と NIC4 を利用する想定
- 4-1: [Network switch for storage] をクリック
- 4-2: [Group management and compute traffic] をクリック
- 4-3: インテント名「Compute_Management」に対して [NIC1] を選択
- 4-4: [+ Select another adapter for this traffic] をクリックして [NIC2] を追加
- 4-5: [Customize network settings] をクリックして「RDMA Protocol」を Disabled に変更
- 4-6: インテント名「Storage」に対して　[NIC3] を選択
- 4-7: 必須項目となっている VLAN ID はデフォルトを受け入れる
   	- ノード間の通信で利用するためのもの
- 4-8: [+ Select another adapter for this traffic] をクリックして [NIC4] 追加
- 4-9: VLAN ID はデフォルトを受け入れる
- 4-10: [Customize network settings] をクリックして「RDMA Protocol」を Disabled に変更
- 4-11: Azure Local が利用する最低 7 つの IP アドレス範囲を用意し、[Starting IP] ~ [Ending IP] として入力
- 4-12: [サブネットマスク　例 255.255.255.0] を入力
- 4-13: [デフォルトゲートウェイのIPアドレス] を入力
- 4-14: [DNS Server のIPアドレス] を入力
- 4-15: [Next: Management] をクリック
#### 5. Management タブ
- 5-1: Azure から Azure Local クラスターに指示を出す際に利用するロケーション名として [任意のCustom location name] を入力
   	- 良く使うので、プロジェクト名や場所、フロアなどを使って、わかりやすい名前を付けておくこと
	- 思い浮かばない時はクラスター名に-cl とつけておくとわかりやすいかも
- 5-2: Cloud witness 用に [Create new]を クリック、さらに右に出てきた内容を確認
	- 必要に応じて修正のうえ、[Create] をクリックし、Azure Storage Account を作成
- 5-3: [ドメイン名 例 contoso.com] を入力
- 5-4: [OU名 　例 OU=test,DC=contoso,DC=com ] を入力　　　※Active Directory の準備の際に設定したOU
- 5-5: Deployment 用の [Username] を入力　　※ Active Directory の準備の際に指定した Deployment 用のユーザー名
- 5-6: [Password]  [Confirm password] を間違えないように入力
- 5-7: Local administrator としての [Username] を入力　　※特別な設定をしていなければ Administrator で OK
- 5-8: [Password]  [Confirm password] を間違えないように入力
- 5-9: [Next: Security] をクリック
#### 6. Security タブ
- [Recommended security settings] が選択されていることを確認し [Next: Advanced] をクリック
	- 古いサーバーを使って展開をする場合など、推奨設定の機能を満たせない場合は [Custommized security settings] をクリックして有効にしたい項目のみを選択
#### 7. Advanced タブ
- [Create workoad volumes and required infrastructure volumes] が選択されていることを確認し[Next: Tags] をクリック
	- 既定で、Software Defined Storage プールに Infrastructure ボリュームと、Azure Local 各ノードを Owner とする論理ボリュームを自動作成してくれる
#### 8. Azure 上のオブジェクトを管理しやすくする任意のタグをつけ、[Next: Validation] をクリック
#### 9. Validation タブ
- 9-1: 特に問題が無ければ Resource Creation として6つの処理を行うため全て Succeeded になることを確認
- 9-2: [Start Validation] をクリック
- 9-3: 更に 11 個のチェックが行われ Validation が完了したら [Next: Preview + Create] をクリック
#### 10. [Create] をクリックし、Azure Local Cluster Deployment を開始
   - 画面が Azure Local 管理画面の ”Settings” にある「Deployments」が選択された状態に遷移するので [Refresh] をクリックして状況を確認できる
   - 手元の 2 ノードで 2 時間半程度かかった
   - "Deploy Arc infrastructure components" ステップでエラーが出る場合 (HCIノードへの接続を繰り返し行いタイムアウト)、Failover Cluster Manager画面の自動作成されたResource Bridge VM のネットワーク設定にて、「Enable MAC address spoofing」を有効にし、「Protected network」を無効にすることでエラー回避可能
   - OS の更新やドメイン参加を含め Azure Local 23H2 クラスター作成作業が自動で行われ、終了すると Azure から管理可能な状態になる
   - 途中エラーが出た場合はログを確認するなどして対処し [Rerun deployment] を実施
