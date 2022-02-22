public with sharing class GitHubUtils {

	public static final String GIT_API_AUTHORIZE_ENDPOINT = 'https://github.com/login/oauth/authorize';
	public static final String GIT_API_TOKEN_ENDPOINT = 'https://github.com/login/oauth/access_token';
	public static final String GIT_API_SETTINGS_NAME = 'GitHubAPI';
	public static final Integer METADATA_API_VERSION = 51;
	public static final String GIT_API_DEFAULT_BRANCH_TIMESTAMP = String.valueOf(DateTime.now().format('YYYY_MM_DD_hh'));
	public static final String GIT_API_DEFAULT_BRANCH_NAME = 'OrgMetadataDump' + GIT_API_DEFAULT_BRANCH_TIMESTAMP;
	public static final String GIT_API_DEFAULT_BASE_BRANCH_REF = ConfigUtil.GIT_API_SETTINGS.Branch_Name__c; //'main',''master;
	public static final String GIT_API_DEFUALT_PULL_REQUST_NAME = 'New Pull Request' + GIT_API_DEFAULT_BRANCH_TIMESTAMP;
	public static final String GIT_API_DEFAULT_COMMIT_MESSAGE = 'Commit sfdx metadata files';
	public static final String GIT_API_DEFAULT_MERGE_COMMIT_TITLE = 'Automatic merge commit';
	public static String LAMBDA_CONVERT_MDAPI_TO_SOURCE_FORMAT = 'https://729a5f6y94.execute-api.us-west-1.amazonaws.com/default/SFDX_Fuction?orgid={0}';
	public static final String EXTRA_PATH_PREFIX = '/tmp/' + UserInfo.getOrganizationId() + '/';

	public static String GIT_USERNAME {
		get {
			if(GIT_USERNAME == null) {
				GIT_USERNAME = ConfigUtil.GIT_API_SETTINGS.Username__c;
			}
			return GIT_USERNAME;
		}
		set;
	}
	public static String GIT_REPONAME {
		get {
			if(GIT_REPONAME == null) {
				GIT_REPONAME = ConfigUtil.GIT_API_SETTINGS.Reponame__c;
			}
			return GIT_REPONAME;
		}
		set;
	}
	public static String GIT_TOKEN {
		get {
			if(GIT_TOKEN == null) {
				GIT_TOKEN = (String.isBlank(ConfigUtil.GIT_API_SETTINGS.Token__c))
					? 'token ' + ConfigUtil.GIT_API_SETTINGS.oAuth_Token__c
					: 'token ' + ConfigUtil.GIT_API_SETTINGS.Token__c;
			}
			return GIT_TOKEN;
		}
		set;
	}
	public static String GIT_API_USER_INFO = 'https://api.github.com/user';
	public static String GIT_API_REPOS_INFO = 'https://api.github.com/users/{0}/repos';
	public static String GIT_API_REPO_BRANCHES_INFO = 'https://api.github.com/repos/{0}/{1}/branches';

	public static String GIT_API_CREATE_TREE = 'https://api.github.com/repos/{0}/{1}/git/trees';
	public static String GET_API_GET_BASE_TREE = 'https://api.github.com/repos/{0}/{1}/branches/{2}';
	public static String GIT_API_GET_HEAD_REFS = 'https://api.github.com/repos/{0}/{1}/git/refs/heads/{2}';
	public static String GIT_API_CREATE_COMMIT = 'https://api.github.com/repos/{0}/{1}/git/commits';
	public static String GIT_API_CREATE_REF = 'https://api.github.com/repos/{0}/{1}/git/refs';
	public static String GIT_API_UPDATE_REF = 'https://api.github.com/repos/{0}/{1}/git/refs/heads/{2}';
	public static String GIT_API_CREATE_PULL = 'https://api.github.com/repos/{0}/{1}/pulls';
	public static String GIT_API_CREATE_MERGE_PULL = 'https://api.github.com/repos/{0}/{1}/pulls/{2}/merge';
	public static final String GIT_API_V3_JSON_HEADER = 'application/vnd.github.v3+json';

	public static List<GitRepoBranchInfo> getRepoBranchesInfos(String reponame) {
		String endpoint = String.format(GIT_API_REPO_BRANCHES_INFO, new List<String>{GIT_USERNAME, reponame});
		String b = HttpUtils.get(
			endpoint,
			GitHubUtils.getGitApiHeaders(),
			200
		);
		List<GitRepoBranchInfo> response = (List<GitRepoBranchInfo>)JSON.deserialize(b, List<GitRepoBranchInfo>.class);
		return response;
	}

	public class GitRepoBranchInfo {
		public String name;
	}

	public static List<GitReposInfo> getReposInfos() {
		String endpoint = String.format(GIT_API_REPOS_INFO, new List<String>{GIT_USERNAME});
		String b = HttpUtils.get(
			endpoint,
			GitHubUtils.getGitApiHeaders(),
			200
		);
		List<GitReposInfo> response = (List<GitReposInfo>)JSON.deserialize(b, List<GitReposInfo>.class);
		return response;
	}

	public class GitReposInfo {
		public String name;
	}

	public static GitUserInfo getGitUserInfo() {
		return getGitUserInfo(GIT_TOKEN);
	}
	public static GitUserInfo getGitUserInfo(String token) {
		String b = HttpUtils.get(
			GIT_API_USER_INFO,
			GitHubUtils.getGitApiHeaders(token),
			200
		);
		GitUserInfo response = (GitUserInfo)JSON.deserialize(b, GitUserInfo.class);
		return response;
	}

	public class GitUserInfo {
		public String login;
	}

	public static MetadataService.MetadataPort getMetadataService() {
		MetadataService.MetadataPort service = new MetadataService.MetadataPort();
		service.SessionHeader = new MetadataService.SessionHeader_element();
		service.SessionHeader.sessionId = UserInfo.getSessionId();
		return service;
	}

	public static MetadataService.RetrieveRequest createRetrieveRequest(String metadataType, String[] members) {
		MetadataService.RetrieveRequest retrieveRequest = new MetadataService.RetrieveRequest();
		retrieveRequest.apiVersion = METADATA_API_VERSION;
		retrieveRequest.packageNames = null;
		retrieveRequest.singlePackage = true;
		retrieveRequest.specificFiles = null;
		retrieveRequest.unpackaged = new MetadataService.Package_x();
		retrieveRequest.unpackaged.types = new List<MetadataService.PackageTypeMembers>();
		MetadataService.PackageTypeMembers packageType = new MetadataService.PackageTypeMembers();
		packageType.name = metadataType;
		packageType.members = members;
		retrieveRequest.unpackaged.types.add(packageType);

		return retrieveRequest;
	}
	public static MetadataService.RetrieveResult getRetrieveRequestResult(String requestId) {
		return  getMetadataService().checkRetrieveStatus(requestId, true);
	}

	public static List<SourceMetadataFile> processMetadataItems(GitHubCommitBatch.MetadataTypeWrapper packageItem) {
		List<SourceMetadataFile> files = new List<SourceMetadataFile>();

		SourceMetadataFolder sourceMetadataFolder;
		MetadataService.RetrieveResult requestResult = GitHubUtils.getRetrieveRequestResult(packageItem.jobId);
		if(requestResult.done) {
			String base64Response = requestResult.zipFile;
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
			}
		}

		return files;
	}

	public static List<SourceMetadataFile> getSourceMetadataFiles(SourceMetadataFolder smf) {
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

	public static String makeCommit(List<SourceMetadataFile> sourceMetadataFiles, String refPath) {
		String refPathResult;
		String headsRef = getHeadRefsSha(GIT_API_DEFAULT_BASE_BRANCH_REF);
		String baseBranchTreeSha = getBaseBranchTreeSha(GIT_API_DEFAULT_BASE_BRANCH_REF);
		String shaTree = gitCreateTree(sourceMetadataFiles, baseBranchTreeSha);
		if(shaTree != null) {
			String shaCommit = gitCreateCommit(shaTree, headsRef);
			refPathResult = (refPath == null) ? gitCreateRef(shaCommit, GIT_API_DEFAULT_BRANCH_NAME) : gitUpdateRef(shaCommit, GIT_API_DEFAULT_BRANCH_NAME);
		}
		return refPathResult;
	}

	public static String getHeadRefsSha(String baseBranch) {
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
	}

	public static String getPullRequestBranchName(String branchName) {
		return GIT_USERNAME + ':' + branchName;
	}

	public static Integer gitCreatePullRequest() {
		Integer pullRequestNumber = GitHubUtils.gitCreatePullRequest(getPullRequestBranchName(GIT_API_DEFAULT_BRANCH_NAME), GIT_API_DEFAULT_BASE_BRANCH_REF, GIT_API_DEFUALT_PULL_REQUST_NAME);
		return pullRequestNumber;
	}

	public static Boolean gitCreateMergePullRequest(Integer pullNumber, String title) {
		String endpoint = String.format(GIT_API_CREATE_MERGE_PULL, new List<String>{GIT_USERNAME, GIT_REPONAME, String.valueOf(pullNumber)});
		String b = HttpUtils.put(
			endpoint,
			getCreateMergePullRequestJSONContent(title),
			getGitApiHeaders(),
			200
		);
		GitCreateMergePullRequestResponse response = (GitCreateMergePullRequestResponse)JSON.deserialize(b, GitCreateMergePullRequestResponse.class);
		return response.merged;
	}

	public static Integer gitCreatePullRequest(String branchName, String baseBranch, String title) {
		String endpoint = String.format(GIT_API_CREATE_PULL, new List<String>{GIT_USERNAME, GIT_REPONAME});
		String b = HttpUtils.post(
			endpoint,
			getCreatePullRequestJSONContent(branchName, baseBranch, title),
			getGitApiHeaders(),
			201
		);
		Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(b);
		Integer pullNumber = (Integer)response.get('number');
		return pullNumber;
	}

	public static String gitCreateRef(String shaCommit, String branchName) {
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

	public static String gitUpdateRef(String shaCommit, String branchName) {
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

	public static String gitCreateCommit(String treeSHA, String masterRefs) {
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

	public static String gitCreateTree(List<SourceMetadataFile> files, String baseTreeSha) {
		String endpoint = String.format(GIT_API_CREATE_TREE, new List<String>{GIT_USERNAME, GIT_REPONAME});
		String treeContent = getCreateTreeJSONContent(files, baseTreeSha);
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

	public static String getCreateMergePullRequestJSONContent(String title) {
		CreateContentMergePullRequest request = new CreateContentMergePullRequest(title);
		return JSON.serialize(request);
	}

	public static String getCreatePullRequestJSONContent(String branchName, String baseBranch, String title) {
		CreateContentPullRequest request = new CreateContentPullRequest(branchName, baseBranch, title);
		return JSON.serialize(request);
	}

	public static String getCreateRefJSONContent(String shaCommit) {
		CreateContentRefRequest request = new CreateContentRefRequest(shaCommit);
		return JSON.serialize(request);
	}

	public static String getCreateRefJSONContent(String shaCommit, String branchName) {
		CreateContentRefRequest request = new CreateContentRefRequest(shaCommit, branchName);
		return JSON.serialize(request);
	}

	public static String getCreateTreeJSONContent(List<SourceMetadataFile> files, String baseTreeSha) {
		CreateContentTreeRequest request = new CreateContentTreeRequest(baseTreeSha);
		for(SourceMetadataFile smf : files) {
			request.addItem(smf.path, smf.body);
		}
		return (request.tree.isEmpty()) ? null : JSON.serialize(request);
	}

	public static String getCreateCommitJSONContent(String shaTree, String commitMessage, String masterRefs) {
		CreateContentCommitRequest request = new CreateContentCommitRequest(commitMessage, shaTree, masterRefs);
		return JSON.serialize(request);
	}

	public class CreateContentMergePullRequest {
		public String commit_title;
		public String merge_method;

		public CreateContentMergePullRequest(String title) {
			this.merge_method = 'squash';
			this.commit_title = title;
		}
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

	public class GitCreateMergePullRequestResponse {
		public String url;
		public String message;
		public Boolean merged;
	}

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
		return getGitApiHeaders(GIT_TOKEN);
	}

	public static Map<String, String> getGitApiHeaders(String token) {
		Map<String, String> headers = HttpUtils.getHeadersAuthorization(token);
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
		public String path;
		public String name;
		public String body;

		public SourceMetadataFile(String path, String name, String body){
			this.path = path;
			this.name = name;
			this.body = body;
		}
	}

	public static List<GitHubCommitBatch.MetadataTypeWrapper> createSubmitRetrieveRequest(GitHubCommitBatch.MetadataTypeWrapper packageItem) {

		List<GitHubCommitBatch.MetadataTypeWrapper> submittedItems = new List<GitHubCommitBatch.MetadataTypeWrapper>();
		MetadataService.RetrieveRequest retrieveRequest = GitHubUtils.createRetrieveRequest(packageItem.type, packageItem.member);
		MetadataService.AsyncResult asyncResult = GitHubUtils.getMetadataService().retrieve(retrieveRequest);
		System.debug('--asyncResult--'+asyncResult);

		if(String.isNotBlank(asyncResult.id)) {
			packageItem.jobId = asyncResult.id;
			submittedItems.add(packageItem);
		}
		return submittedItems;
	}
}