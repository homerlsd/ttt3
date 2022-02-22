public with sharing class GitHubCommitBatch2 implements Database.batchable<Sobject>,Database.Stateful, Database.AllowsCallouts,Database.RaisesPlatformEvents {

	public Enum BATCH_MODE {
		SUBMIT_RETRIEVE_REQUEST,
		PROCESS_METADATA_ITEMS
	}

	private String gitHubCommitId;
	private BATCH_MODE currentMode;
	private String refPath;

	private List<SourceMetadataFile> gitFiles = new List<SourceMetadataFile>();

	public static final String GIT_HUB_COMMIT_STATUS_NEW = 'New';
	public static final String GIT_HUB_COMMIT_STATUS_COMMITED = 'Commited';
	public static final String GIT_HUB_COMMIT_STATUS_FAILED = 'Failed';

	public GitHubCommitBatch2() {
		this.currentMode = BATCH_MODE.SUBMIT_RETRIEVE_REQUEST;
		this.gitHubCommitId = getGitHubCommitId();
	}

	public GitHubCommitBatch2(BATCH_MODE batchMode, String githubCommitId) {
		this.currentMode = batchMode;
		this.gitHubCommitId = gitHubCommitId;
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		Database.QueryLocator queryLocator;

		if(this.currentMode == BATCH_MODE.SUBMIT_RETRIEVE_REQUEST) {
			queryLocator = Database.getQueryLocator([
					SELECT Id, Member__c, Type__c
					FROM Git_Subscription__c
			]);
		}
		else if(this.currentMode == BATCH_MODE.PROCESS_METADATA_ITEMS) {
			queryLocator = Database.getQueryLocator([
					SELECT Id, Git_Commit__c, Retrieve_Request_Id__c
					FROM Git_Commit_Item__c
					WHERE Git_Commit__c = :this.gitHubCommitId
					AND Status__c = :GIT_HUB_COMMIT_STATUS_NEW
			]);
		}

		return queryLocator;
	}

	public void execute(Database.batchableContext info, List<SObject> scope) {
		switch on this.currentMode {
			when SUBMIT_RETRIEVE_REQUEST {
				List<Git_Subscription__c> scopeItems = (List<Git_Subscription__c>)scope;
				List<Git_Commit_Item__c> commitItems = createSubmitRetrieveRequest(scopeItems.get(0));
				if(!commitItems.isEmpty()) {
					insert commitItems;
				}

			}
			when PROCESS_METADATA_ITEMS {
				List<Git_Commit_Item__c> scopeItems = (List<Git_Commit_Item__c>)scope;
				List<SourceMetadataFile> files = processMetadataItems(scopeItems.get(0));
				//this.gitFiles.addAll(files);
				makeCommit(files);
			}
		}
	}

	public void finish(Database.BatchableContext BC) {
		switch on this.currentMode {
			when SUBMIT_RETRIEVE_REQUEST {
				Database.executeBatch(new GitHubCommitBatch2(BATCH_MODE.PROCESS_METADATA_ITEMS, this.gitHubCommitId), 1);
			}
			when PROCESS_METADATA_ITEMS {
				String pull = gitCreatePullRequest(getPullRequestBranchName(GIT_API_DEFAULT_BRANCH_NAME), GIT_API_DEFAULT_BASE_BRANCH_REF, GIT_API_DEFUALT_PULL_REQUST_NAME);

//				if(!this.gitFiles.isEmpty()) {
//					makeCommit(this.gitFiles);
//				}
			}
		}
	}

	public static String LAMBDA_CONVERT_MDAPI_TO_SOURCE_FORMAT = 'https://729a5f6y94.execute-api.us-west-1.amazonaws.com/default/SFDX_Fuction?orgid={0}';

	public static String GIT_USERNAME {
		get {
			if(GIT_USERNAME == null) {
				GIT_USERNAME = 'homerlsd';
			}
			return GIT_USERNAME;
		}
		set;
	}
	public static String GIT_REPONAME {
		get {
			if(GIT_REPONAME == null) {
				GIT_REPONAME = 'ttt';
			}
			return GIT_REPONAME;
		}
		set;
	}
	public static String GIT_TOKEN {
		get {
			if(GIT_TOKEN == null) {
				GIT_TOKEN = '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';
			}
			return GIT_TOKEN;
		}
		set;
	}
	// https://api.github.com/repos/homerlsd/ttt/git/blobs
	public static String GIT_API_CREATE_BLOB = 'https://api.github.com/repos/{0}/{1}/git/blobs';
	// https://api.github.com/repos/homerlsd/ttt/git/trees
	public static String GIT_API_CREATE_TREE = 'https://api.github.com/repos/{0}/{1}/git/trees';
	public static String GET_API_GET_BASE_TREE = 'https://api.github.com/repos/{0}/{1}/branches/{2}';
	public static String GIT_API_GET_HEAD_REFS = 'https://api.github.com/repos/{0}/{1}/git/refs/heads/{2}';
	public static String GIT_API_CREATE_COMMIT = 'https://api.github.com/repos/{0}/{1}/git/commits';
	public static String GIT_API_CREATE_REF = 'https://api.github.com/repos/{0}/{1}/git/refs';
	public static String GIT_API_UPDATE_REF = 'https://api.github.com/repos/{0}/{1}/git/refs/heads/{2}';
	public static String GIT_API_CREATE_PULL = 'https://api.github.com/repos/{0}/{1}/pulls';
	public static final String GIT_API_V3_JSON_HEADER = 'application/vnd.github.v3+json';


	private List<SourceMetadataFile> processMetadataItems(Git_Commit_Item__c gitCommitItem) {
		List<SourceMetadataFile> files = new List<SourceMetadataFile>();

		SourceMetadataFolder sourceMetadataFolder;
		String base64Response = GitHubUtils.getRetrieveRequestZipFile(gitCommitItem.Retrieve_Request_Id__c);
		if(String.isNotBlank(base64Response)) {
			String endpoint = String.format(LAMBDA_CONVERT_MDAPI_TO_SOURCE_FORMAT, new List<String>{UserInfo.getOrganizationId()});
			String b = HttpUtils.post(
					endpoint,
					base64Response,
					HttpUtils.getHeadersContentType('text/plain'),
					200
			);
			sourceMetadataFolder = (SourceMetadataFolder)JSON.deserialize(b, SourceMetadataFolder.class);
			files = getSourceMetadataFiles(sourceMetadataFolder);
			//files = pullMetadataFilesToGit(sourceMetadataFiles);
		}
		return files;
	}

	private static List<SourceMetadataFile> getSourceMetadataFiles(SourceMetadataFolder smf) {
		List<SourceMetadataFile> result = new List<SourceMetadataFile>();

		if(smf != null) {
			if(smf.type == 'file') {
				result.add(new SourceMetadataFile(smf.path, smf.name, smf.body));
			}
			if(smf.children != null) {
				for(SourceMetadataFolder childSmf : smf.children) {
					result.addAll(getSourceMetadataFiles(childSmf));
				}
			}
		}
		return result;
	}

	private static List<SourceMetadataFile> pullMetadataFilesToGit(List<SourceMetadataFile> sourceMetadataFiles) {
		List<SourceMetadataFile> result = new List<SourceMetadataFile>();

		for(SourceMetadataFile smf : sourceMetadataFiles) {
			String sha = gitCreateBlob(smf.body);
			if(String.isNotBlank(sha)) {
				result.add(smf.addSha(sha));
			}
		}

		return result;
	}

	public static final String GIT_API_DEFAULT_BRANCH_TIMESTAMP = String.valueOf(DateTime.now().format('YYYY_MM_DD_hh'));
	public static final String GIT_API_DEFAULT_BRANCH_NAME = 'metadataStamp' + GIT_API_DEFAULT_BRANCH_TIMESTAMP;
	public static final String GIT_API_DEFAULT_BASE_BRANCH_REF = 'main';
	public static final String GIT_API_DEFUALT_PULL_REQUST_NAME = 'new PR' + GIT_API_DEFAULT_BRANCH_TIMESTAMP;

	private void makeCommit(List<SourceMetadataFile> sourceMetadataFiles) {
		String headsRef = getHeadRefsSha(GIT_API_DEFAULT_BASE_BRANCH_REF);

		String baseBranchTreeSha = getBaseBranchTreeSha(GIT_API_DEFAULT_BASE_BRANCH_REF);
		String shaTree = gitCreateTree(sourceMetadataFiles, baseBranchTreeSha);
		if(shaTree != null) {
			String shaCommit = gitCreateCommit(shaTree, headsRef);

			if(this.refPath == null) {
				String refPath = gitCreateRef(shaCommit, GIT_API_DEFAULT_BRANCH_NAME);
				this.refPath = refPath;
			}
			else {
				String refPath = gitUpdateRef(shaCommit, GIT_API_DEFAULT_BRANCH_NAME);
				this.refPath = refPath;
			}
		}

		//gitCreateRef(shaCommit, GIT_API_DEFAULT_BRANCH_NAME);
		//String pull = gitCreatePullRequest(getPullRequestBranchName(GIT_API_DEFAULT_BRANCH_NAME), GIT_API_DEFAULT_BASE_BRANCH_REF, GIT_API_DEFUALT_PULL_REQUST_NAME);
		//gitCreatePullRequest(refPath, GIT_API_DEFAULT_BASE_BRANCH_REF);
	}

	private static String getHeadRefsSha(String baseBranch) {
		String endpoint = String.format(GIT_API_GET_HEAD_REFS, new List<String>{GIT_USERNAME, GIT_REPONAME, baseBranch});
		String b = HttpUtils.get(
				endpoint,
				getGitApiHeaders(),
				200
		);
		Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(b);
		Map<String, Object> objectRef = (Map<String, Object>)response.get('object');
		String sha = (String)objectRef.get('sha');
		return sha;
	}


	public static String getBaseBranchTreeSha(String baseBranch) {

		String endpoint = String.format(GET_API_GET_BASE_TREE, new List<String>{GIT_USERNAME, GIT_REPONAME, baseBranch});
		String b = HttpUtils.get(
				endpoint,
				getGitApiHeaders(),
				200
		);
		Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(b);
		Map<String, Object> commit1 = (Map<String, Object>)response.get('commit');
		Map<String, Object> commitInfo = (Map<String, Object>)commit1.get('commit');
		Map<String, Object> tree = (Map<String, Object>)commitInfo.get('tree');
		String sha = (String)tree.get('sha');
		return sha;
		//GitBaseBranchResponse response = (GitBaseBranchResponse)JSON.deserialize(b, GitBaseBranchResponse.class);
		//return null;//response.commit.commit.tree.sha;
	}

	private static String getPullRequestBranchName(String branchName) {
		return GIT_USERNAME + ':' + branchName;
	}

	private static String gitCreatePullRequest(String branchName, String baseBranch, String title) {
		String endpoint = String.format(GIT_API_CREATE_PULL, new List<String>{GIT_USERNAME, GIT_REPONAME});
		String b = HttpUtils.post(
				endpoint,
				getCreatePullRequestJSONContent(branchName, baseBranch, title),
				getGitApiHeaders(),
				201
		);
		GitCreatePullRequestResponse response = (GitCreatePullRequestResponse)JSON.deserialize(b, GitCreatePullRequestResponse.class);
		return response.url;
	}

	private static String gitCreateRef(String shaCommit, String branchName) {
		String endpoint = String.format(GIT_API_CREATE_REF, new List<String>{GIT_USERNAME, GIT_REPONAME});
		String b = HttpUtils.post(
			endpoint,
			getCreateRefJSONContent(shaCommit, branchName),
			getGitApiHeaders(),
			201
		);
		GitCreateRefResponse response = (GitCreateRefResponse)JSON.deserialize(b, GitCreateRefResponse.class);
		return response.ref;
	}

	private static String gitUpdateRef(String shaCommit, String branchName) {
		String endpoint = String.format(GIT_API_UPDATE_REF, new List<String>{GIT_USERNAME, GIT_REPONAME, branchName});
		String b = HttpUtils.patch(
			endpoint,
			getCreateRefJSONContent(shaCommit),
			getGitApiHeaders(),
			200
		);
		GitCreateRefResponse response = (GitCreateRefResponse)JSON.deserialize(b, GitCreateRefResponse.class);
		return response.ref;
	}

	public static final String GIT_API_DEFAULT_COMMIT_MESSAGE = 'commit sfdx metadata files';

	private static String gitCreateCommit(String treeSHA, String masterRefs) {
		String endpoint = String.format(GIT_API_CREATE_COMMIT, new List<String>{GIT_USERNAME, GIT_REPONAME});
		String b = HttpUtils.post(
				endpoint,
				getCreateCommitJSONContent(treeSHA, GIT_API_DEFAULT_COMMIT_MESSAGE, masterRefs),
				getGitApiHeaders(),
				201
		);
		GitCreateCommitResponse response = (GitCreateCommitResponse)JSON.deserialize(b, GitCreateCommitResponse.class);
		return response.sha;
	}

	private static String gitCreateTree(List<SourceMetadataFile> files, String baseTreeSha) {
		String endpoint = String.format(GIT_API_CREATE_TREE, new List<String>{GIT_USERNAME, GIT_REPONAME});
		String treeContent = getCreateTreeJSONContent(files, baseTreeSha);
		system.debug('---getCreateTreeJSONContent--'+treeContent);
		if(treeContent != null) {
			String b = HttpUtils.post(
				endpoint,
				getCreateTreeJSONContent(files, baseTreeSha),
				getGitApiHeaders(),
				201
			);
			GitCreateTreeResponse response = (GitCreateTreeResponse)JSON.deserialize(b, GitCreateTreeResponse.class);
			return response.sha;
		}
		return null;
	}

	private static String getCreatePullRequestJSONContent(String branchName, String baseBranch, String title) {
		CreateContentPullRequest request = new CreateContentPullRequest(branchName, baseBranch, title);
		return JSON.serialize(request);
	}

	private static String getCreateRefJSONContent(String shaCommit) {
		CreateContentRefRequest request = new CreateContentRefRequest(shaCommit);
		return JSON.serialize(request);
	}

	private static String getCreateRefJSONContent(String shaCommit, String branchName) {
		CreateContentRefRequest request = new CreateContentRefRequest(shaCommit, branchName);
		return JSON.serialize(request);
	}

	private static String getCreateTreeJSONContent(List<SourceMetadataFile> files, String baseTreeSha) {
		CreateContentTreeRequest request = new CreateContentTreeRequest(baseTreeSha);
		for(SourceMetadataFile smf : files) {
			request.addItem(smf.path, smf.body);
			//request.addItem(smf.path, smf.sha);
		}
		return (request.tree.isEmpty()) ? null : JSON.serialize(request);
	}

	private static String getCreateCommitJSONContent(String shaTree, String commitMessage, String masterRefs) {
		CreateContentCommitRequest request = new CreateContentCommitRequest(commitMessage, shaTree, masterRefs);
		return JSON.serialize(request);
	}

	public class CreateContentPullRequest {
		public String head;
		public String base;
		public String title;

		public CreateContentPullRequest(String head, String base, String title) {
			this.head = head;
			this.base = base;
			this.title = title;
		}
	}

	public class CreateContentRefRequest {
		public String ref;
		public String sha;
		public Boolean force;

		public CreateContentRefRequest(String sha) {
			this.ref = null;
			this.sha = sha;
			this.force = true;
		}

		public CreateContentRefRequest(String sha, String branchName) {
			this(sha, branchName, false);
		}

		public CreateContentRefRequest(String sha, String branchName, Boolean force) {
			this.ref = 'refs/heads/' + branchName;
			this.sha = sha;
			this.force = force;
		}
	}

	public class CreateContentCommitRequest {
		public String tree;
		public String message;
		public List<String> parents;

		public CreateContentCommitRequest(String commitMessage, String treeSHA, String masterRefs) {
			this.tree = treeSHA;
			this.message = commitMessage;
			this.parents = new List<String>{masterRefs};
		}
	}

	public class CreateContentTreeRequest {
		public String base_tree;
		public List<CreateContentTreeItem> tree;

		public CreateContentTreeRequest(String baseTreeSha) {
			this.base_tree = baseTreeSha;
			this.tree = new List<CreateContentTreeItem>();
		}

		public void addItem(String path, String content) {
			addItem(new CreateContentTreeItem(path, content));
		}

		public void addItem(CreateContentTreeItem item) {
			this.tree.add(item);
		}
	}

	public class CreateContentTreeItem {
		public String path;
		public String mode;
		public String type;
		public String content;

		public CreateContentTreeItem(String path, String content) {
			this.mode = '100644';
			this.type = 'blob';
			this.path = path.replace(EXTRA_PATH_PREFIX, '');
			this.content = content;
		}
	}

	private static final String EXTRA_PATH_PREFIX = '/tmp/' + UserInfo.getOrganizationId() + '/';

	private static String gitCreateBlob(String content) {
		String endpoint = String.format(GIT_API_CREATE_BLOB, new List<String>{GIT_USERNAME, GIT_REPONAME});

		String b = HttpUtils.post(
				endpoint,
				getCreateBlobJSONContent(content),
				getGitApiHeaders(),
				201
		);

		GitCreateBlobResponse response = (GitCreateBlobResponse)JSON.deserialize(b, GitCreateBlobResponse.class);
		return response.sha;
	}

	public static String getCreateBlobJSONContent(String content) {
		return JSON.serialize(new Map<String, Object>{
				'content' => content
		});
	}

/*
	public class GitBaseBranchCommitTreeInfo {
		public String sha;
	}

	public class GitBaseBranchCommitInfo {
		public String sha;
		public GitBaseBranchCommitTreeInfo tree;
	}

	public class GitBaseBranchCommit {
		public String sha;
		public GitBaseBranchCommitInfo commit;
	}

	public class GitBaseBranchResponse {
		public String name;
		public GitBaseBranchCommit commit;
	}
	*/

	public class GitCreatePullRequestResponse {
		public String url;
	}

	public class GitCreateRefResponse {
		public String ref;
		public String url;
	}

	public class GitCreateCommitResponse {
		public String sha;
		public String url;
	}

	public class GitCreateTreeResponse {
		public String sha;
		public String url;
	}

	public class GitCreateBlobResponse {
		public String sha;
		public String url;
	}

	public static Map<String, String> getGitApiHeaders() {
		Map<String, String> headers = HttpUtils.getHeadersAuthorization('token ' + GIT_TOKEN);
		headers.putAll(HttpUtils.getHeadersAccept(GIT_API_V3_JSON_HEADER));
		return headers;
	}

	public class SourceMetadataFolder {
		// full path
		public String path;
		// folder or file name
		public String name;
		// folder, file
		public String type;
		// related folders and files
		public List<SourceMetadataFolder> children;
		// body of file
		public String body;

		public SourceMetadataFolder(){}
	}

	public class SourceMetadataFile {
		//public String sha;
		public String path;
		public String name;
		public String body;

		public SourceMetadataFile(String path, String name, String body){
			this.path = path;
			this.name = name;
			this.body = body;
		}

		public SourceMetadataFile addSha(String sha) {
			this.body = null;
			//this.sha = sha;
			return this;
		}
	}



	private List<Git_Commit_Item__c> createSubmitRetrieveRequest(Git_Subscription__c gitSubscription) {
		if(String.isBlank(this.gitHubCommitId)) return new List<Git_Commit_Item__c>();

		List<Git_Commit_Item__c> existItems = [
				SELECT Id, Retrieve_Request_Id__c
				FROM Git_Commit_Item__c
				WHERE Git_Commit__c = :this.gitHubCommitId
				AND Git_Subscription__c = :gitSubscription.Id
				LIMIT 1
		];
		if(!existItems.isEmpty() && String.isNotBlank(existItems.get(0).Retrieve_Request_Id__c)) {
			return new List<Git_Commit_Item__c>();
		}

		List<Git_Commit_Item__c> commitItems = new List<Git_Commit_Item__c>();
		MetadataService.RetrieveRequest retrieveRequest = GitHubUtils.createRetrieveRequest(gitSubscription.Type__c, new String[] {gitSubscription.Member__c});
		MetadataService.AsyncResult asyncResult = GitHubUtils.getMetadataService().retrieve(retrieveRequest);
		System.debug('--asyncResult--'+asyncResult);

		if(String.isNotBlank(asyncResult.id)) {
			commitItems.add(
					new Git_Commit_Item__c(
							Git_Commit__c = this.gitHubCommitId,
							Git_Subscription__c	= gitSubscription.Id,
							Status__c = GIT_HUB_COMMIT_STATUS_NEW,
							Retrieve_Request_Id__c = asyncResult.id
					)
			);
		}
		return commitItems;
	}

	private static String getGitHubCommitId() {
		List<Git_Commit__c> commits = [
				SELECT Id
				FROM Git_Commit__c
				WHERE Completed__c = false
				ORDER BY CreatedDate DESC
				LIMIT 1
		];
		return (!commits.isEmpty()) ? commits.get(0).Id : null;
	}

}