@IsTest
private class GitHubCommitBatchTest {

	private static final String TEST_GIT_API_USERNAME = 'someusername';
	private static final String TEST_GIT_API_TOKEN = 'token';
	private static final String TEST_GIT_API_OAUTH_TOKEN = 'oauthtoken';
	private static final String TEST_GIT_API_REPONAME = 'reponame';
	private static final String TEST_GIT_API_BRANCH_NAME = 'master';

	@TestSetup
	private static void testSetup() {
		ConfigUtil.GIT_API_SETTINGS.Username__c = TEST_GIT_API_USERNAME;
		ConfigUtil.GIT_API_SETTINGS.Token__c = TEST_GIT_API_TOKEN;
		ConfigUtil.GIT_API_SETTINGS.oauth_Token__c = TEST_GIT_API_OAUTH_TOKEN;
		ConfigUtil.GIT_API_SETTINGS.Reponame__c = TEST_GIT_API_REPONAME;
		ConfigUtil.GIT_API_SETTINGS.Branch_Name__c = TEST_GIT_API_BRANCH_NAME;
		upsert ConfigUtil.GIT_API_SETTINGS;
	}

	@IsTest
	static void test_audit_trail_changes_apex_class() {
		GitHubCommitBatch.MAP_ENABLED_METADATA = new Map<String, Boolean>{
			GitHubCommitBatch.METADATA_TYPE_APEX_CLASS => true
		};

		createMockApexClasses(new List<String>{'someApexClassName','someChangedApexClass'});

		Test.setMock(WebServiceMock.class, new MetadataSubmitRetrieveWebServiceMockImpl(getSubmitRetrieveAsyncResult()));

		ConfigUtil.GIT_API_SETTINGS.Last_Processed_Id__c = 'someId';
		upsert ConfigUtil.GIT_API_SETTINGS;

		Map<String, Object> dataMap = new Map<String, Object>();
		dataMap.put('Id', 'someNewTrailId');
		dataMap.put('Display', 'someChangedApexClass');
		dataMap.put('Section', GitHubCommitBatch.AUDIT_TRAIL_SECTION_APEX_CLASS);
		List<Map<String, Object>> dataMapList = new List<Map<String, Object>>();
		dataMapList.add(dataMap);

		GitHubCommitBatch.mockAuditTrails = (List<SetupAuditTrail>)JSON.deserialize(JSON.serialize(dataMapList), List<SetupAuditTrail>.class);

		Test.startTest();
		List<GitHubCommitBatch.MetadataTypeWrapper> items = GitHubCommitBatch.getMetadataTypeMembers();
		Test.stopTest();
		system.assertEquals(1, items.size());
		system.assertEquals(true, items.get(0).member.contains('someChangedApexClass'));
		system.assertEquals('someNewTrailId', ConfigUtil.GIT_API_SETTINGS.Last_Processed_Id__c);
	}

	@IsTest
	static void test_get_git_user_info() {
		GitHubUtils.GitUserInfo userInfo;

		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(getGitAPIUserEndpoint(), getGitAPIUserMock());

		HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		Test.startTest();
		userInfo = GitHubUtils.getGitUserInfo(TEST_GIT_API_TOKEN);
		Test.stopTest();

		System.assertEquals(TEST_GIT_API_USERNAME, userInfo.login);
	}

	@IsTest
	static void test_get_git_user_repos() {
		List<GitHubUtils.GitReposInfo> reposInfo;

		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(getGitAPIUserReposEndpoint(), getGitAPIUserReposMock());

		HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		Test.startTest();
		reposInfo = GitHubUtils.getReposInfos();
		Test.stopTest();

		System.assertEquals(1, reposInfo.size());
		System.assertEquals(TEST_GIT_API_REPONAME, reposInfo.get(0).name);
	}

	@IsTest
	static void test_get_git_user_repo_branches() {
		List<GitHubUtils.GitRepoBranchInfo> repoBranchesInfo;

		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(getGitAPIUserRepoBranchesEndpoint(), getGitAPIUserRepoBranchesMock());

		HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		Test.startTest();
		repoBranchesInfo = GitHubUtils.getRepoBranchesInfos(TEST_GIT_API_REPONAME);
		Test.stopTest();

		System.assertEquals(1, repoBranchesInfo.size());
		System.assertEquals(TEST_GIT_API_BRANCH_NAME, repoBranchesInfo.get(0).name);
	}

	@IsTest
	static void test_commit_apex_classes() {
		List<GitHubCommitBatch.MetadataTypeWrapper> apexClasses = createPackageItems(GitHubCommitBatch.METADATA_TYPE_APEX_CLASS);
		GitHubCommitBatch.putMetadataPackageItemsToCache(apexClasses);

		MetadataService.RetrieveResult retrieveResult = new MetadataService.RetrieveResult();
		retrieveResult.done = true;
		retrieveResult.zipFile = TEST_RETRIEVE_RESPONSE_ZIP;
		Test.setMock(WebServiceMock.class, new MetadataRetrieveResultWebServiceMockImpl(retrieveResult));

		Map<String, HttpCalloutMock> endpoint2TestResp = new Map<String, HttpCalloutMock>();
		endpoint2TestResp.put(getAWSEndpointConvertMDAPItoSourceFormatRequestMock(), getAWSConvertMDAPItoSourceFormatRequestMock());
		endpoint2TestResp.put(getGitAPIRefsEndpoint(), getGitAPIRefsMock());
		endpoint2TestResp.put(getGitHeadTreeCommitShaEndpoint(), getGitHeadTreeCommitShaMock());
		endpoint2TestResp.put(getGitCreateTreeEndpoint(), getGitCreateTreeMock());
		endpoint2TestResp.put(gitCreateCommitEndpoint(), gitCreateCommitMock());
		endpoint2TestResp.put(gitCreateRefEndpoint(), gitCreateRefMock());
		endpoint2TestResp.put(gitCreatePullRequestEndpoint(), gitCreatePullRequestMock());
		endpoint2TestResp.put(gitCreateMergePullRequestEndpoint(), gitCreateMergePullRequestMock());

		HttpCalloutMock multiCalloutMock = new TestDataFactory.MultiRequestMock(endpoint2TestResp);
		Test.setMock(HttpCalloutMock.class, multiCalloutMock);

		Test.startTest();
		Database.executeBatch(new GitHubCommitBatch(GitHubCommitBatch.BATCH_MODE.PROCESS_METADATA_ITEMS), 1);
		Test.stopTest();
	}

	private static String gitCreateMergePullRequestEndpoint() {
		String endpoint = String.format(GitHubUtils.GIT_API_CREATE_MERGE_PULL, new List<String>{TEST_GIT_API_USERNAME, TEST_GIT_API_REPONAME, String.valueOf(GIT_API_CREATE_PULL_NUMBER)});
		return endpoint;
	}
	private static TestDataFactory.SingleRequestMock gitCreateMergePullRequestMock() {
		Map<String, Object> objectCreatePull = new Map<String, Object> {
			'merged' => true
		};

		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			200,
			'OK',
			JSON.serialize(objectCreatePull)
		);
		return singleRequestMock;
	}

	private static String gitCreatePullRequestEndpoint() {
		String endpoint = String.format(GitHubUtils.GIT_API_CREATE_PULL, new List<String>{TEST_GIT_API_USERNAME, TEST_GIT_API_REPONAME});
		return endpoint;
	}
	private static final Integer GIT_API_CREATE_PULL_NUMBER = 1;
	private static TestDataFactory.SingleRequestMock gitCreatePullRequestMock() {
		Map<String, Object> objectCreatePull = new Map<String, Object> {
			'number' => GIT_API_CREATE_PULL_NUMBER
		};

		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			201,
			'OK',
			JSON.serialize(objectCreatePull)
		);
		return singleRequestMock;
	}

	private static String gitCreateRefEndpoint() {
		String endpoint = String.format(GitHubUtils.GIT_API_CREATE_REF, new List<String>{TEST_GIT_API_USERNAME, TEST_GIT_API_REPONAME});
		return endpoint;
	}
	private static final String GIT_API_CREATE_REF = 'someCreateRef';
	private static TestDataFactory.SingleRequestMock gitCreateRefMock() {
		Map<String, Object> objectCreateRef = new Map<String, Object> {
			'ref' => GIT_API_CREATE_REF
		};

		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			201,
			'OK',
			JSON.serialize(objectCreateRef)
		);
		return singleRequestMock;
	}

	private static String gitCreateCommitEndpoint() {
		String endpoint = String.format(GitHubUtils.GIT_API_CREATE_COMMIT, new List<String>{TEST_GIT_API_USERNAME, TEST_GIT_API_REPONAME});
		return endpoint;
	}
	private static final String GIT_API_CREATE_COMMIT_SHA = 'someCreateCommitsha';
	private static TestDataFactory.SingleRequestMock gitCreateCommitMock() {
		Map<String, Object> objectCreateCommit = new Map<String, Object> {
			'sha' => GIT_API_CREATE_COMMIT_SHA
		};

		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			201,
			'OK',
			JSON.serialize(objectCreateCommit)
		);
		return singleRequestMock;
	}

	private static String getGitCreateTreeEndpoint() {
		String endpoint = String.format(GitHubUtils.GIT_API_CREATE_TREE, new List<String>{TEST_GIT_API_USERNAME, TEST_GIT_API_REPONAME});
		return endpoint;
	}
	private static final String GIT_API_CREATE_TREE_SHA = 'someCreateTreesha';
	private static TestDataFactory.SingleRequestMock getGitCreateTreeMock() {
		Map<String, Object> objectCreateTree = new Map<String, Object> {
			'sha' => GIT_API_CREATE_TREE_SHA
		};

		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			201,
			'OK',
			JSON.serialize(objectCreateTree)
		);
		return singleRequestMock;
	}

	private static String getGitHeadTreeCommitShaEndpoint() {
		String endpoint = String.format(GitHubUtils.GET_API_GET_BASE_TREE, new List<String>{TEST_GIT_API_USERNAME, TEST_GIT_API_REPONAME, TEST_GIT_API_BRANCH_NAME});
		return endpoint;
	}
	private static final String GIT_API_HEAD_TREE_COMMIT_SHA = 'someHeadTreeCommitsha';
	private static TestDataFactory.SingleRequestMock getGitHeadTreeCommitShaMock() {
		Map<String, Object> objectTree = new Map<String, Object> {
			'commit' => new Map<String, Object>{
				'commit' => new Map<String, Object>{
					'tree' => new Map<String, Object>{
						'sha' => GIT_API_HEAD_TREE_COMMIT_SHA
					}
				}
			}
		};

		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			200,
			'OK',
			JSON.serialize(objectTree)
		);
		return singleRequestMock;
	}

	private static String getGitAPIRefsEndpoint() {
		String endpoint = String.format(GitHubUtils.GIT_API_GET_HEAD_REFS, new List<String>{TEST_GIT_API_USERNAME, TEST_GIT_API_REPONAME, TEST_GIT_API_BRANCH_NAME});
		return endpoint;
	}
	private static final String GIT_API_HEAD_REF_SHA = 'someHeadRefsha';
	private static TestDataFactory.SingleRequestMock getGitAPIRefsMock() {
		Map<String, Object> objectRef = new Map<String, Object> {
			'object' => new Map<String, Object>{
				'sha' => GIT_API_HEAD_REF_SHA
			}
		};

		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			200,
			'OK',
			JSON.serialize(objectRef)
		);
		return singleRequestMock;
	}

	private static String getAWSEndpointConvertMDAPItoSourceFormatRequestMock() {
		String endpoint = String.format(GitHubUtils.LAMBDA_CONVERT_MDAPI_TO_SOURCE_FORMAT, new List<String>{UserInfo.getOrganizationId()});
		return endpoint;
	}

	private static TestDataFactory.SingleRequestMock getAWSConvertMDAPItoSourceFormatRequestMock() {
		GitHubUtils.SourceMetadataFolder folder = new GitHubUtils.SourceMetadataFolder();
		folder.path = '/tmp/folder1';
		folder.name = 'folder1';
		folder.type = 'folder';
		folder.children = new List<GitHubUtils.SourceMetadataFolder>();
		GitHubUtils.SourceMetadataFolder file = new GitHubUtils.SourceMetadataFolder();
		folder.path = '/tmp/folder1/file1.cls';
		folder.name = 'file';
		folder.type = 'file';
		folder.body = 'somefilebody';
		folder.children.add(file);

		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			200,
			'OK',
			JSON.serialize(folder)
		);
		return singleRequestMock;
	}

	private static String getGitAPIUserEndpoint() {
		return GitHubUtils.GIT_API_USER_INFO;
	}
	private static TestDataFactory.SingleRequestMock getGitAPIUserMock() {
		Map<String, Object> objectUser = new Map<String, Object> {
			'login' => TEST_GIT_API_USERNAME
		};

		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			200,
			'OK',
			JSON.serialize(objectUser)
		);
		return singleRequestMock;
	}

	private static String getGitAPIUserReposEndpoint() {
		String endpoint = String.format(GitHubUtils.GIT_API_REPOS_INFO, new List<String>{GitHubUtils.GIT_USERNAME});
		return endpoint;
	}
	private static TestDataFactory.SingleRequestMock getGitAPIUserReposMock() {
		List<Map<String, Object>> objectRepos = new List<Map<String, Object>>{
			new Map<String, Object> {
				'name' => TEST_GIT_API_REPONAME
			}
		};

		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			200,
			'OK',
			JSON.serialize(objectRepos)
		);
		return singleRequestMock;
	}

	private static String getGitAPIUserRepoBranchesEndpoint() {
		String endpoint = String.format(GitHubUtils.GIT_API_REPO_BRANCHES_INFO, new List<String>{GitHubUtils.GIT_USERNAME, TEST_GIT_API_REPONAME});
		return endpoint;
	}
	private static TestDataFactory.SingleRequestMock getGitAPIUserRepoBranchesMock() {
		List<Map<String, Object>> objectRepos = new List<Map<String, Object>>{
			new Map<String, Object> {
				'name' => TEST_GIT_API_BRANCH_NAME
			}
		};

		TestDataFactory.SingleRequestMock singleRequestMock = new TestDataFactory.SingleRequestMock(
			200,
			'OK',
			JSON.serialize(objectRepos)
		);
		return singleRequestMock;
	}

	static List<GitHubCommitBatch.MetadataTypeWrapper> createPackageItems(String type) {
		List<GitHubCommitBatch.MetadataTypeWrapper> result = new List<GitHubCommitBatch.MetadataTypeWrapper>();
		GitHubCommitBatch.MetadataTypeWrapper wrapper = new GitHubCommitBatch.MetadataTypeWrapper(type, TEST_RETRIEVE_ELEMENT_MEMBER);
		wrapper.jobId = TEST_RETRIEVE_ELEMENT_ID;
		result.add(wrapper);
		return result;
	}

	private static MetadataService.AsyncResult getSubmitRetrieveAsyncResult() {
		MetadataService.AsyncResult asyncResult = new MetadataService.AsyncResult();
		asyncResult.id = TEST_RETRIEVE_ELEMENT_ID;
		// in progress
		asyncResult.done = false;
		return asyncResult;
	}

	private static void assertRetrieveMetadataIsSubmitted(String expectedMetadataType) {
		List<GitHubCommitBatch.MetadataTypeWrapper> cachedMetadataPackageItems = GitHubCommitBatch.getMetadataPackageItemsFromCache();
		System.assertNotEquals(null, cachedMetadataPackageItems);
		System.assertEquals(1, cachedMetadataPackageItems.size());
		System.assertEquals(TEST_RETRIEVE_ELEMENT_ID, cachedMetadataPackageItems.get(0).jobId);
		System.assertEquals(expectedMetadataType, cachedMetadataPackageItems.get(0).type);
	}

	@IsTest
	static void test_submit_retrieve_remote_site_settings() {
		GitHubCommitBatch.MAP_ENABLED_METADATA = new Map<String, Boolean>{
			GitHubCommitBatch.METADATA_TYPE_REMOTE_SITE_SETTINGS => true
		};

		Test.setMock(WebServiceMock.class, new MetadataSubmitRetrieveWebServiceMockImpl(getSubmitRetrieveAsyncResult()));

		Test.startTest();
		Database.executeBatch(new GitHubCommitBatch(), 1);
		Test.stopTest();

		assertRetrieveMetadataIsSubmitted(GitHubCommitBatch.METADATA_TYPE_REMOTE_SITE_SETTINGS);
	}

	@IsTest
	static void test_submit_retrieve_workflows() {
		GitHubCommitBatch.MAP_ENABLED_METADATA = new Map<String, Boolean>{
			GitHubCommitBatch.METADATA_TYPE_WORKFLOW => true
		};

		Test.setMock(WebServiceMock.class, new MetadataSubmitRetrieveWebServiceMockImpl(getSubmitRetrieveAsyncResult()));

		Test.startTest();
		Database.executeBatch(new GitHubCommitBatch(), 1);
		Test.stopTest();

		assertRetrieveMetadataIsSubmitted(GitHubCommitBatch.METADATA_TYPE_WORKFLOW);
	}

	@IsTest
	static void test_submit_retrieve_approval_processes() {
		GitHubCommitBatch.MAP_ENABLED_METADATA = new Map<String, Boolean>{
			GitHubCommitBatch.METADATA_TYPE_APPROVAL_PROCESS => true
		};

		Test.setMock(WebServiceMock.class, new MetadataSubmitRetrieveWebServiceMockImpl(getSubmitRetrieveAsyncResult()));

		Test.startTest();
		Database.executeBatch(new GitHubCommitBatch(), 1);
		Test.stopTest();

		assertRetrieveMetadataIsSubmitted(GitHubCommitBatch.METADATA_TYPE_APPROVAL_PROCESS);
	}

	@IsTest
	static void test_submit_retrieve_aura_elements() {
		GitHubCommitBatch.MAP_ENABLED_METADATA = new Map<String, Boolean>{
			GitHubCommitBatch.METADATA_TYPE_AURA => true
		};

		Test.setMock(WebServiceMock.class, new MetadataSubmitRetrieveWebServiceMockImpl(getSubmitRetrieveAsyncResult()));

		Test.startTest();
		Database.executeBatch(new GitHubCommitBatch(), 1);
		Test.stopTest();

		assertRetrieveMetadataIsSubmitted(GitHubCommitBatch.METADATA_TYPE_AURA);
	}

	@IsTest
	static void test_submit_retrieve_connected_apps() {
		GitHubCommitBatch.MAP_ENABLED_METADATA = new Map<String, Boolean>{
			GitHubCommitBatch.METADATA_TYPE_CONNECTED_APP => true
		};

		Test.setMock(WebServiceMock.class, new MetadataSubmitRetrieveWebServiceMockImpl(getSubmitRetrieveAsyncResult()));

		Test.startTest();
		Database.executeBatch(new GitHubCommitBatch(), 1);
		Test.stopTest();

		assertRetrieveMetadataIsSubmitted(GitHubCommitBatch.METADATA_TYPE_CONNECTED_APP);
	}

	@IsTest
	static void test_submit_retrieve_named_creds() {
		GitHubCommitBatch.MAP_ENABLED_METADATA = new Map<String, Boolean>{
			GitHubCommitBatch.METADATA_TYPE_NAMED_CREDENTIAL => true
		};

		Test.setMock(WebServiceMock.class, new MetadataSubmitRetrieveWebServiceMockImpl(getSubmitRetrieveAsyncResult()));

		Test.startTest();
		Database.executeBatch(new GitHubCommitBatch(), 1);
		Test.stopTest();

		assertRetrieveMetadataIsSubmitted(GitHubCommitBatch.METADATA_TYPE_NAMED_CREDENTIAL);
	}

	@IsTest
	static void test_submit_retrieve_custom_metadata() {
		GitHubCommitBatch.MAP_ENABLED_METADATA = new Map<String, Boolean>{
			GitHubCommitBatch.METADATA_TYPE_CUSTOM_METADATA => true
		};

		Test.setMock(WebServiceMock.class, new MetadataSubmitRetrieveWebServiceMockImpl(getSubmitRetrieveAsyncResult()));

		Test.startTest();
		Database.executeBatch(new GitHubCommitBatch(), 1);
		Test.stopTest();

		assertRetrieveMetadataIsSubmitted(GitHubCommitBatch.METADATA_TYPE_CUSTOM_METADATA);
	}

	private static void createMockApexClasses(List<String> apexClassNames) {
		GitHubCommitBatch.mockListApexClasses = new List<ApexClass>();

		List<Map<String, Object>> dataMapList = new List<Map<String, Object>>();
		for(String className : apexClassNames) {
			Map<String, Object> dataMap = new Map<String, Object>();
			dataMap.put('Name', className);
			dataMap.put('LengthWithoutComments', 1);
			dataMapList.add(dataMap);
		}
		GitHubCommitBatch.mockListApexClasses = (List<ApexClass>)JSON.deserialize(JSON.serialize(dataMapList), List<ApexClass>.class);
	}

	@IsTest
	static void test_submit_retrieve_apex_classes() {
		GitHubCommitBatch.MAP_ENABLED_METADATA = new Map<String, Boolean>{
			GitHubCommitBatch.METADATA_TYPE_APEX_CLASS => true
		};
		createMockApexClasses(new List<String>{'someApexClassName'});

		Test.setMock(WebServiceMock.class, new MetadataSubmitRetrieveWebServiceMockImpl(getSubmitRetrieveAsyncResult()));

		Test.startTest();
		Database.executeBatch(new GitHubCommitBatch(), 1);
		Test.stopTest();

		assertRetrieveMetadataIsSubmitted(GitHubCommitBatch.METADATA_TYPE_APEX_CLASS);
	}

	@IsTest
	static void test_submit_retrieve_apex_triggers() {
		GitHubCommitBatch.MAP_ENABLED_METADATA = new Map<String, Boolean>{
			GitHubCommitBatch.METADATA_TYPE_APEX_TRIGGER => true
		};

		Test.setMock(WebServiceMock.class, new MetadataSubmitRetrieveWebServiceMockImpl(getSubmitRetrieveAsyncResult()));

		Test.startTest();
		Database.executeBatch(new GitHubCommitBatch(), 1);
		Test.stopTest();

		assertRetrieveMetadataIsSubmitted(GitHubCommitBatch.METADATA_TYPE_APEX_TRIGGER);
	}

	@IsTest
	static void test_submit_retrieve_metadata_flows() {
		GitHubCommitBatch.MAP_ENABLED_METADATA = new Map<String, Boolean>{
			GitHubCommitBatch.METADATA_TYPE_FLOW => true
		};

		Test.setMock(WebServiceMock.class, new MetadataSubmitRetrieveWebServiceMockImpl(getSubmitRetrieveAsyncResult()));

		Test.startTest();
		Database.executeBatch(new GitHubCommitBatch(), 1);
		Test.stopTest();

		assertRetrieveMetadataIsSubmitted(GitHubCommitBatch.METADATA_TYPE_FLOW);
	}

	@IsTest
	static void test_submit_retrieve_metadata_custom_objects() {
		GitHubCommitBatch.MAP_ENABLED_METADATA = new Map<String, Boolean>{
			GitHubCommitBatch.METADATA_TYPE_CUSTOM_OBJECT => true
		};

		Test.setMock(WebServiceMock.class, new MetadataSubmitRetrieveWebServiceMockImpl(getSubmitRetrieveAsyncResult()));

		Test.startTest();
		Database.executeBatch(new GitHubCommitBatch(), 1);
		Test.stopTest();

		assertRetrieveMetadataIsSubmitted(GitHubCommitBatch.METADATA_TYPE_CUSTOM_OBJECT);
	}

	public static final String TEST_RETRIEVE_ELEMENT_ID = 'testId';
	public static final String TEST_RETRIEVE_ELEMENT_MEMBER = 'someMember';
	public static final String TEST_RETRIEVE_RESPONSE_ZIP = 'someBase64ZipContent';

	public static final String TEST_WORKFLOW_ELEMENT_API_NAME = 'someWorkflowAPIName';
	public static final String TEST_APPROVAL_PROCESS_ELEMENT_API_NAME = 'someApprovalAPIName';
	public static final String TEST_AURA_ELEMENT_API_NAME = 'someAuraAPIName';
	public static final String TEST_RSS_ELEMENT_API_NAME = 'someRssAPIName';
	public static final String TEST_APP_ELEMENT_API_NAME = 'someAppAPIName';
	public static final String TEST_CREDS_ELEMENT_API_NAME = 'someCredsAPIName';
	public static final String TEST_CUSTOM_METADATA_ELEMENT_API_NAME = 'someCustomMetaPIName';

	public static final Map<String, String> TEST_MAP_DEFAULT_DESCRIBE_LIST_COMPONENTS = new Map<String, String>{
		GitHubCommitBatch.METADATA_TYPE_WORKFLOW => TEST_WORKFLOW_ELEMENT_API_NAME,
		GitHubCommitBatch.METADATA_TYPE_APPROVAL_PROCESS => TEST_APPROVAL_PROCESS_ELEMENT_API_NAME,
		GitHubCommitBatch.METADATA_TYPE_AURA => TEST_AURA_ELEMENT_API_NAME,
		GitHubCommitBatch.METADATA_TYPE_REMOTE_SITE_SETTINGS => TEST_RSS_ELEMENT_API_NAME,
		GitHubCommitBatch.METADATA_TYPE_CONNECTED_APP => TEST_APP_ELEMENT_API_NAME,
		GitHubCommitBatch.METADATA_TYPE_NAMED_CREDENTIAL => TEST_CREDS_ELEMENT_API_NAME,
		GitHubCommitBatch.METADATA_TYPE_CUSTOM_METADATA => TEST_CUSTOM_METADATA_ELEMENT_API_NAME
	};

	public static List<MetadataService.FileProperties> getDefaultListDescribeElements() {
		List<MetadataService.FileProperties> result = new List<MetadataService.FileProperties>();
		for(String metaType : TEST_MAP_DEFAULT_DESCRIBE_LIST_COMPONENTS.keySet()) {
			MetadataService.FileProperties fp = new MetadataService.FileProperties();
			fp.fullName = TEST_MAP_DEFAULT_DESCRIBE_LIST_COMPONENTS.get(metaType);
			fp.type_x = metaType;
			result.add(fp);
		}
		return result;
	}

	public class MetadataSubmitRetrieveWebServiceMockImpl implements WebServiceMock {
		private MetadataService.AsyncResult asyncResult;
		private MetadataService.FileProperties[] fileProperties;

		public MetadataSubmitRetrieveWebServiceMockImpl(MetadataService.AsyncResult asyncResult) {
			this(asyncResult, getDefaultListDescribeElements());
		}

		public MetadataSubmitRetrieveWebServiceMockImpl(MetadataService.AsyncResult asyncResult, MetadataService.FileProperties[] fileProperties) {
			this.asyncResult = asyncResult;
			this.fileProperties = fileProperties;
		}
		public void doInvoke(
				Object stub,
				Object request,
				Map<String, Object> response,
				String endpoint,
				String soapAction,
				String requestName,
				String responseNS,
				String responseName,
				String responseType) {

			if(request instanceof MetadataService.listMetadata_element) {
				MetadataService.listMetadataResponse_element listMetadataResponseElement = new MetadataService.listMetadataResponse_element();
				listMetadataResponseElement.result = this.fileProperties;
				response.put('response_x', listMetadataResponseElement);
			}
			else if (request instanceof MetadataService.retrieve_element) {
				MetadataService.retrieveResponse_element retrieveResponseElement = new MetadataService.retrieveResponse_element();
				retrieveResponseElement.result = this.asyncResult;
				response.put('response_x', retrieveResponseElement);
			}
		}
	}

	public class MetadataRetrieveResultWebServiceMockImpl implements WebServiceMock {
		private MetadataService.RetrieveResult asyncResult;
		private MetadataService.FileProperties[] fileProperties;

		public MetadataRetrieveResultWebServiceMockImpl(MetadataService.RetrieveResult asyncResult) {
			this(asyncResult, getDefaultListDescribeElements());
		}

		public MetadataRetrieveResultWebServiceMockImpl(MetadataService.RetrieveResult asyncResult, MetadataService.FileProperties[] fileProperties) {
			this.asyncResult = asyncResult;
			this.fileProperties = fileProperties;
		}
		public void doInvoke(
			Object stub,
			Object request,
			Map<String, Object> response,
			String endpoint,
			String soapAction,
			String requestName,
			String responseNS,
			String responseName,
			String responseType) {

			if(request instanceof MetadataService.listMetadata_element) {
				MetadataService.listMetadataResponse_element listMetadataResponseElement = new MetadataService.listMetadataResponse_element();
				listMetadataResponseElement.result = this.fileProperties;
				response.put('response_x', listMetadataResponseElement);
			}
			else if (request instanceof MetadataService.checkRetrieveStatus_element) {
				MetadataService.checkRetrieveStatusResponse_element retrieveResponseElement = new MetadataService.checkRetrieveStatusResponse_element();
				retrieveResponseElement.result = this.asyncResult;
				response.put('response_x', retrieveResponseElement);
			}

		}
	}
}