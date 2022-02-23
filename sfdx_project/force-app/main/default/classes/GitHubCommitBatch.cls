public with sharing class GitHubCommitBatch implements Database.batchable<MetadataTypeWrapper>,Database.Stateful, Database.AllowsCallouts,Database.RaisesPlatformEvents {

	public Enum BATCH_MODE {
		SUBMIT_RETRIEVE_REQUEST,
		PROCESS_METADATA_ITEMS
	}
	private BATCH_MODE currentMode;
	private String refPath;
	private List<MetadataTypeWrapper> incompletedPackageItems = new List<MetadataTypeWrapper>();

	public GitHubCommitBatch() {
		this(BATCH_MODE.SUBMIT_RETRIEVE_REQUEST);
	}

	public GitHubCommitBatch(BATCH_MODE batchMode) {
		this.currentMode = batchMode;
	}

	public GitHubCommitBatch(BATCH_MODE batchMode, List<MetadataTypeWrapper> incompletedPackageItems) {
		this.currentMode = batchMode;
		this.incompletedPackageItems = incompletedPackageItems;
	}

	public Iterable<MetadataTypeWrapper> start(Database.BatchableContext bc) {
		MetadataTypeIterable iterable;

		if(this.currentMode == BATCH_MODE.SUBMIT_RETRIEVE_REQUEST) {
			iterable = new MetadataTypeIterable(getMetadataTypeMembers());
		}
		else if(this.currentMode == BATCH_MODE.PROCESS_METADATA_ITEMS) {
			if(!this.incompletedPackageItems.isEmpty()) {
				iterable = new MetadataTypeIterable(this.incompletedPackageItems);
				this.incompletedPackageItems.clear();
			}
			else {
				iterable = new MetadataTypeIterable(getMetadataPackageItemsFromCache());
			}
		}
		return iterable;
	}

	public void execute(Database.batchableContext info, List<MetadataTypeWrapper> scope) {
		switch on this.currentMode {
			when SUBMIT_RETRIEVE_REQUEST {
				List<MetadataTypeWrapper> scopeItems = (List<MetadataTypeWrapper>)scope;
				List<MetadataTypeWrapper> retrieveItems = GitHubUtils.createSubmitRetrieveRequest(scopeItems.get(0));
				if(!retrieveItems.isEmpty()) {
					putMetadataPackageItemsToCache(retrieveItems);
				}
			}
			when PROCESS_METADATA_ITEMS {
				List<MetadataTypeWrapper> scopeItems = (List<MetadataTypeWrapper>)scope;
				List<GitHubUtils.SourceMetadataFile> files = GitHubUtils.processMetadataItems(scopeItems.get(0));
				if(files.isEmpty()) {
					this.incompletedPackageItems.add(scopeItems.get(0));
				}
				else {
					this.refPath = GitHubUtils.makeCommit(files, this.refPath);
				}
			}
		}
	}

	public void finish(Database.BatchableContext BC) {
		switch on this.currentMode {
			when SUBMIT_RETRIEVE_REQUEST {
				if(!Test.isRunningTest()) {
					Database.executeBatch(new GitHubCommitBatch(BATCH_MODE.PROCESS_METADATA_ITEMS), 1);
				}
			}
			when PROCESS_METADATA_ITEMS {
				if(!this.incompletedPackageItems.isEmpty() && !Test.isRunningTest()) {
					Database.executeBatch(new GitHubCommitBatch(BATCH_MODE.PROCESS_METADATA_ITEMS, this.incompletedPackageItems), 1);
				}
				else if(String.isNotBlank(this.refPath)) {
					Integer pullNumber = GitHubUtils.gitCreatePullRequest();
					Boolean isMerged = GitHubUtils.gitCreateMergePullRequest(pullNumber, GitHubUtils.GIT_API_DEFAULT_MERGE_COMMIT_TITLE);
				}
			}
		}
	}

	public class MetadataTypeIterable implements Iterable<MetadataTypeWrapper> {

		private List<MetadataTypeWrapper> packageItems;

		public MetadataTypeIterable() {
			this.packageItems = new List<MetadataTypeWrapper>();
		}

		public MetadataTypeIterable(List<MetadataTypeWrapper> packageItems) {
			this.packageItems = packageItems;
		}

		public Iterator<MetadataTypeWrapper> iterator() {
			return new MetadataTypeIterator(this.packageItems);
		}
	}

	public class MetadataTypeIterator implements Iterator<MetadataTypeWrapper> {
		private List<MetadataTypeWrapper> packageItems;
		private Integer index;

		public MetadataTypeIterator(List<MetadataTypeWrapper> defaults) {
			this.packageItems = defaults == null ? new List<MetadataTypeWrapper>() : defaults;
			this.index = 0;
		}

		public MetadataTypeIterator() {
			this(new List<MetadataTypeWrapper>());
		}

		public Boolean hasNext() {
			return this.index < packageItems.size() ? true : false;
		}

		public MetadataTypeWrapper next() {
			return this.packageItems[this.index++];
		}
	}

	// soql types
	public static final String METADATA_TYPE_FLOW = 'Flow';
	public static final String METADATA_TYPE_APEX_CLASS = 'ApexClass';
	public static final String METADATA_TYPE_APEX_TRIGGER = 'ApexTrigger';
	public static final String METADATA_TYPE_CUSTOM_OBJECT = 'CustomObject';
	public static final String METADATA_TYPE_APEX_PAGE = 'ApexPage';
	public static final String METADATA_TYPE_APEX_COMPONENT = 'ApexComponent';

	// metadata query types
	public static final String METADATA_TYPE_WORKFLOW = 'Workflow';
	public static final String METADATA_TYPE_APPROVAL_PROCESS = 'ApprovalProcess';
	public static final String METADATA_TYPE_AURA = 'AuraDefinitionBundle';
	public static final String METADATA_TYPE_REMOTE_SITE_SETTINGS = 'RemoteSiteSetting';
	public static final String METADATA_TYPE_CONNECTED_APP = 'ConnectedApp';
	public static final String METADATA_TYPE_NAMED_CREDENTIAL = 'NamedCredential';
	public static final String METADATA_TYPE_CUSTOM_METADATA = 'CustomMetadata';

	public static Map<String, Boolean> MAP_ENABLED_METADATA = new Map<String, Boolean>{
		METADATA_TYPE_FLOW => true,
		METADATA_TYPE_APEX_CLASS => true,
		METADATA_TYPE_APEX_TRIGGER => true,
		METADATA_TYPE_CUSTOM_OBJECT => true,
		METADATA_TYPE_APEX_PAGE => true,
		METADATA_TYPE_APEX_COMPONENT => true,
		METADATA_TYPE_WORKFLOW => true,
		METADATA_TYPE_APPROVAL_PROCESS => true,
		METADATA_TYPE_AURA => true,
		METADATA_TYPE_REMOTE_SITE_SETTINGS => true,
		METADATA_TYPE_CONNECTED_APP => true,
		METADATA_TYPE_NAMED_CREDENTIAL => true,
		METADATA_TYPE_CUSTOM_METADATA => true
	};

	public static final String AUDIT_TRAIL_SECTION_APEX_CLASS = 'Apex Class';
	public static final String AUDIT_TRAIL_SECTION_APEX_TRIGGER = 'Apex Trigger';
	public static final String AUDIT_TRAIL_SECTION_FLOWS = 'Flows';
	public static final String AUDIT_TRAIL_SECTION_CUSTOM_OBJECTS = 'Custom Objects';
	public static final String AUDIT_TRAIL_SECTION_APEX_PAGE = 'Page';
	public static final String AUDIT_TRAIL_SECTION_APEX_COMPONENT = 'Component';
	public static final String AUDIT_TRAIL_SECTION_APPROVAL_PROCESS = 'Approval Process';
	public static final String AUDIT_TRAIL_SECTION_WORKFLOW = 'Workflow Rule';
	public static final String AUDIT_TRAIL_SECTION_AURA = 'Lightning Components';
	public static final String AUDIT_TRAIL_SECTION_REMOTE_SITE_SETTINGS = 'Security Controls';
	public static final String AUDIT_TRAIL_SECTION_CONNECTED_APP = 'Connected Apps';
	public static final String AUDIT_TRAIL_SECTION_CONNECTED_APP2 = 'Application';
	public static final String AUDIT_TRAIL_SECTION_NAMED_CREDENTIAL = 'Named Credentials';
	public static final String AUDIT_TRAIL_SECTION_CUSTOM_METADATA = 'Custom Metadata Types';


	public static Map<String, String> MAP_METADATA_TYPE_BY_AUDIT_ACTION = new Map<String, String>{
		AUDIT_TRAIL_SECTION_FLOWS => METADATA_TYPE_FLOW,
		AUDIT_TRAIL_SECTION_APEX_CLASS => METADATA_TYPE_APEX_CLASS,
		AUDIT_TRAIL_SECTION_APEX_TRIGGER => METADATA_TYPE_APEX_TRIGGER,
		AUDIT_TRAIL_SECTION_CUSTOM_OBJECTS => METADATA_TYPE_CUSTOM_OBJECT,
		AUDIT_TRAIL_SECTION_APEX_PAGE => METADATA_TYPE_APEX_PAGE,
		AUDIT_TRAIL_SECTION_APEX_COMPONENT => METADATA_TYPE_APEX_COMPONENT,
		AUDIT_TRAIL_SECTION_WORKFLOW => METADATA_TYPE_WORKFLOW,
		AUDIT_TRAIL_SECTION_APPROVAL_PROCESS => METADATA_TYPE_APPROVAL_PROCESS,
		AUDIT_TRAIL_SECTION_AURA => METADATA_TYPE_AURA,
		AUDIT_TRAIL_SECTION_REMOTE_SITE_SETTINGS => METADATA_TYPE_REMOTE_SITE_SETTINGS,
		AUDIT_TRAIL_SECTION_CONNECTED_APP => METADATA_TYPE_CONNECTED_APP,
		AUDIT_TRAIL_SECTION_CONNECTED_APP2 => METADATA_TYPE_CONNECTED_APP,
		AUDIT_TRAIL_SECTION_NAMED_CREDENTIAL => METADATA_TYPE_NAMED_CREDENTIAL,
		AUDIT_TRAIL_SECTION_CUSTOM_METADATA => METADATA_TYPE_CUSTOM_METADATA
	};

	public static List<MetadataTypeWrapper> getMetadataTypeMembers() {
		List<MetadataTypeWrapper> result = new List<MetadataTypeWrapper>();
		// return all metadata items
		if(String.isBlank(ConfigUtil.GIT_API_SETTINGS.Last_Processed_Id__c)) {
			result = getDefaultMetadataTypeMembers();
			setLastProcessedId(getAuditTrails(null).lastProcessedId);
		}
		// return only changed metadata
		else {
			AuditChangeWrapper lastChanges = getAuditTrails(ConfigUtil.GIT_API_SETTINGS.Last_Processed_Id__c);
			if(!lastChanges.auditChange.isEmpty()) {
				result = getFilteredMetadataTypeMembers(lastChanges.auditChange);
				setLastProcessedId(lastChanges.lastProcessedId);
			}
		}
		return result;
	}

	public static void setLastProcessedId(String lastProcessedId) {
		if(String.isNotBlank(lastProcessedId)) {
			ConfigUtil.GIT_API_SETTINGS.Last_Processed_Id__c = lastProcessedId;
			update ConfigUtil.GIT_API_SETTINGS;
		}
	}

	public class AuditChangeWrapper {
		public List<AuditChange> auditChange;
		public String lastProcessedId;

		public AuditChangeWrapper(String lastProcessedId) {
			this.auditChange = new List<AuditChange>();
			this.lastProcessedId = lastProcessedId;
		}

		public AuditChangeWrapper(List<AuditChange> auditChange, String lastProcessedId) {
			this.auditChange = auditChange;
			this.lastProcessedId = lastProcessedId;
		}
	}
	public class AuditChange {
		public String type;
		public List<String> changes;

		public AuditChange(String type) {
			this.type = type;
			this.changes = new List<String>();
		}

		public void addChange(String change) {
			this.changes.add(change);
		}
	}

	public class MetaWrapper {
		public String apiName;
		public Integer size;

		public MetaWrapper(String apiName) {
			this(apiName, 1);
		}
		public MetaWrapper(String apiName, Integer size) {
			this.apiName = apiName;
			this.size = size;
		}
	}

	public static MetadataTypeWrapperContainer getMetaTypeContainer(Boolean permission, String metaType) {
		MetadataTypeWrapperContainer result = new MetadataTypeWrapperContainer();
		if(!permission) return result;

		if(metaType == METADATA_TYPE_APEX_CLASS || metaType == METADATA_TYPE_APEX_TRIGGER) {
			for(MetaWrapper item : METADATA_BUNDLE.get(metaType)) {
				result.addMember(metaType, item.apiName, item.size);
			}
		}
		else {
			result.members = new List<MetadataTypeWrapper>{new MetadataTypeWrapper(metaType, '*')};
		}
		return result;
	}

	public static MetadataTypeWrapperContainer getMetaTypeContainer(Boolean permission, String metaType, List<String> changes) {
		MetadataTypeWrapperContainer result = new MetadataTypeWrapperContainer();
		if(!permission) return result;

		if(metaType == METADATA_TYPE_CUSTOM_OBJECT) {
			result.members = new List<MetadataTypeWrapper>{new MetadataTypeWrapper(METADATA_TYPE_CUSTOM_OBJECT, '*')};
			return result;
		}

		for(String auditChange : changes) {
			for(MetaWrapper item : METADATA_BUNDLE.get(metaType)) {
				if(auditChange.containsIgnoreCase(item.apiName)) {
					result.addMember(metaType, item.apiName, item.size);
				}
			}
		}
		return result;
	}

	public static List<MetadataTypeWrapper> getDefaultMetadataTypeMembers() {
		List<MetadataTypeWrapper> result = new List<MetadataTypeWrapper>();
		for(String metaType : MAP_ENABLED_METADATA.keySet()) {
			MetadataTypeWrapperContainer metaTypeContainer = getMetaTypeContainer(
				MAP_ENABLED_METADATA.get(metaType),
				metaType
			);
			if(!metaTypeContainer.members.isEmpty()) {
				result.addAll(metaTypeContainer.members);
			}
		}
		return result;
	}

	public static List<MetadataTypeWrapper> getFilteredMetadataTypeMembers(List<AuditChange> auditChanges) {
		List<MetadataTypeWrapper> result = new List<MetadataTypeWrapper>();
		for(AuditChange auditChange : auditChanges) {
			MetadataTypeWrapperContainer metaTypeContainer = getMetaTypeContainer(
				MAP_ENABLED_METADATA.get(auditChange.type),
				auditChange.type,
				auditChange.changes
			);
			if(!metaTypeContainer.members.isEmpty()) {
				result.addAll(metaTypeContainer.members);
			}
		}
		return result;
	}

	@TestVisible
	private static AuditChangeWrapper testAuditChangeWrapper;

	@TestVisible
	private static List<SetupAuditTrail> mockAuditTrails = new List<SetupAuditTrail>();

	private static List<SetupAuditTrail> getAuditTrailRecords(String lastProcessedId) {
		List<SetupAuditTrail> records;
		if(lastProcessedId == null) {
			records = Test.isRunningTest() ? mockAuditTrails : [
				SELECT Id, Action, CreatedDate, Display, Section
				FROM SetupAuditTrail
				ORDER BY CreatedDate DESC
				LIMIT 1
			];
		}
		else {
			records = Test.isRunningTest() ? mockAuditTrails : [
				SELECT Id, Action, CreatedDate, Display, Section
				FROM SetupAuditTrail
				WHERE Id > :lastProcessedId
				ORDER BY CreatedDate DESC
			];
		}
		return records;
	}

	public static AuditChangeWrapper getAuditTrails(String lastProcessedId) {
		AuditChangeWrapper result;

		if(testAuditChangeWrapper != null) {
			result = testAuditChangeWrapper;
			return result;
		}
		List<SetupAuditTrail> records = getAuditTrailRecords(lastProcessedId);

		if(lastProcessedId == null) {
			String currentLastProcessedId = records.isEmpty() ? null : records.get(0).Id;
			result = new AuditChangeWrapper(currentLastProcessedId);
		}
		else {
			Integer lastIndex = !records.isEmpty() ? records.size() - 1 : null;
			String currentLastProcessedId = (lastIndex != null) ? records.get(lastIndex).Id : null;

			Map<String, AuditChange> changes = new Map<String, AuditChange>();
			for(SetupAuditTrail record : records) {
				AuditChange change;
				String metaType = MAP_METADATA_TYPE_BY_AUDIT_ACTION.get(record.Section);
				if(String.isNotBlank(metaType)) {
					change = changes.get(metaType) != null ? changes.get(metaType) : new AuditChange(metaType);
					change.addChange(record.Display);
					changes.put(metaType, change);
				}
			}
			result = new AuditChangeWrapper(changes.values(), currentLastProcessedId);
		}
		return result;
	}

	@TestVisible
	private static Integer limitRecordsMetadataType = Test.isRunningTest() ? 1 : 5000;

	public static List<FlowDefinitionView> getListFlows() {
		List<FlowDefinitionView> result = [
			SELECT ApiName, NamespacePrefix, Label, IsActive
			FROM FlowDefinitionView
			WHERE NamespacePrefix = NULL
				OR NamespacePrefix = :ConfigUtil.currentOrgNameSpacePrefix
			LIMIT :limitRecordsMetadataType
		];
		return result;
	}

	@TestVisible
	private static List<ApexClass> mockListApexClasses = new List<ApexClass>();

	public static List<ApexClass> getListApexClasses() {
		List<ApexClass> result = Test.isRunningTest() ? mockListApexClasses : [
			SELECT LengthWithoutComments, NamespacePrefix, Name
			FROM ApexClass
			WHERE NamespacePrefix = NULL
				OR NamespacePrefix = :ConfigUtil.currentOrgNameSpacePrefix
			LIMIT :limitRecordsMetadataType
		];
		return result;
	}

	public static List<ApexTrigger> getListApexTriggers() {
		List<ApexTrigger> result = [
			SELECT LengthWithoutComments, NamespacePrefix, Name
			FROM ApexTrigger
			WHERE NamespacePrefix = NULL
			OR NamespacePrefix = :ConfigUtil.currentOrgNameSpacePrefix
			LIMIT :limitRecordsMetadataType
		];
		return result;
	}

	public static List<ApexPage> getListApexPages() {
		List<ApexPage> result = [
			SELECT Id, NamespacePrefix, Name
			FROM ApexPage
			WHERE NamespacePrefix = NULL
			OR NamespacePrefix = :ConfigUtil.currentOrgNameSpacePrefix
			LIMIT :limitRecordsMetadataType
		];
		return result;
	}

	public static List<ApexComponent> getListApexComponents() {
		List<ApexComponent> result = [
			SELECT Id, NamespacePrefix, Name
			FROM ApexComponent
			WHERE NamespacePrefix = NULL
			OR NamespacePrefix = :ConfigUtil.currentOrgNameSpacePrefix
			LIMIT :limitRecordsMetadataType
		];
		return result;
	}

	public static Map<String, List<MetaWrapper>> METADATA_BUNDLE {
		get {
			if(METADATA_BUNDLE == null) {
				METADATA_BUNDLE = getMetadata(
					new List<String>{
						METADATA_TYPE_REMOTE_SITE_SETTINGS,
						METADATA_TYPE_CONNECTED_APP,
						METADATA_TYPE_NAMED_CREDENTIAL
					}
				);
				METADATA_BUNDLE.putAll(getMetadata(
					new List<String>{
						METADATA_TYPE_WORKFLOW,
						METADATA_TYPE_APPROVAL_PROCESS,
						METADATA_TYPE_AURA
					}
				));
				METADATA_BUNDLE.putAll(getMetadata(
					new List<String>{
						METADATA_TYPE_CUSTOM_METADATA
					}
				));

				METADATA_BUNDLE.putAll(getMetadata(
					METADATA_TYPE_APEX_CLASS,
					getListApexClasses(),
					'',
					'Name',
					'LengthWithoutComments'
				));
				METADATA_BUNDLE.putAll(getMetadata(
					METADATA_TYPE_APEX_TRIGGER,
					getListApexTriggers(),
					'',
					'Name',
					'LengthWithoutComments'
				));
				METADATA_BUNDLE.putAll(getMetadata(
					METADATA_TYPE_APEX_PAGE,
					getListApexPages(),
					'',
					'Name'
				));
				METADATA_BUNDLE.putAll(getMetadata(
					METADATA_TYPE_APEX_COMPONENT,
					getListApexComponents(),
					'',
					'Name'
				));
				METADATA_BUNDLE.putAll(getMetadata(
					METADATA_TYPE_FLOW,
					getListFlows(),
					'',
					'ApiName'
				));
			}
			return METADATA_BUNDLE;
		}
		set;
	}

	public static Map<String, List<MetaWrapper>> getMetadata(String type, List<SObject> records, String nameSpaceField, String apiNameField) {
		return getMetadata(type, records, nameSpaceField, apiNameField, '');
	}
	public static Map<String, List<MetaWrapper>> getMetadata(String type, List<SObject> records, String nameSpaceField, String apiNameField, String sizeField) {
		Map<String, List<MetaWrapper>> result = new Map<String, List<MetaWrapper>>();

		for(SObject so : records) {
			List<MetaWrapper> packageItems = result.get(type) != null
				? result.get(type)
				: new List<MetaWrapper>();
			String apiName = String.isNotBlank(nameSpaceField) ? (String.valueOf(so.get(nameSpaceField)) + '__') : '';
			apiName += String.valueOf(so.get(apiNameField));
			Integer sizeItem = String.isNotBlank(sizeField) ? Integer.valueOf(so.get(sizeField)) : 1;
			packageItems.add(new MetaWrapper(apiName, sizeItem));
			result.put(type, packageItems);
		}
		return result;
	}

	public static Map<String, List<MetaWrapper>> getMetadata(List<String> metadataTypes) {
		Map<String, List<MetaWrapper>> result = new Map<String, List<MetaWrapper>>();

		List<MetadataService.ListMetadataQuery> queries = new List<MetadataService.ListMetadataQuery>();
		for(String metadataType : metadataTypes) {
			MetadataService.ListMetadataQuery query = new MetadataService.ListMetadataQuery();
			query.type_x = metadataType;
			queries.add(query);
		}
		MetadataService.FileProperties[] fileProperties = GitHubUtils.getMetadataService().listMetadata(queries, GitHubUtils.METADATA_API_VERSION);
		for(MetadataService.FileProperties fileProperty : fileProperties) {
			List<MetaWrapper> packageItems = result.get(fileProperty.type_x) != null
				? result.get(fileProperty.type_x)
				: new List<MetaWrapper>();
			packageItems.add(new MetaWrapper(fileProperty.fullName));
			result.put(fileProperty.type_x, packageItems);
		}

		return result;
	}

	public static List<MetadataTypeWrapper> getMetadataPackageItemsFromCache() {
		CacheUtils cacheUtil = new CacheUtils('');
		Object cacheObject = cacheUtil.getValue(CacheUtils.KEY_REQUEST_METADATA_RETRIEVE_REQUEST);
		return (List<MetadataTypeWrapper>)cacheObject;
	}

	public static void putMetadataPackageItemsToCache(List<MetadataTypeWrapper> packageItems) {
		CacheUtils cacheUtil = new CacheUtils('');
		List<MetadataTypeWrapper> existPackageItems = getMetadataPackageItemsFromCache();
		if(existPackageItems == null || existPackageItems.isEmpty()) {
			existPackageItems = new List<MetadataTypeWrapper>();
		}
		existPackageItems.addAll(packageItems);
		cacheUtil.putValue(CacheUtils.KEY_REQUEST_METADATA_RETRIEVE_REQUEST, existPackageItems);
	}

	public static final Integer METADATA_CONTAINER_ITEM_MAX_SIZE = 1000000; //1mb

	public class MetadataTypeWrapperContainer {
		public List<MetadataTypeWrapper> members;
		public Integer currentContainerSize = 0;

		public MetadataTypeWrapperContainer() {
			this.members = new List<MetadataTypeWrapper>();
		}

		public void addMember(String type, String member, Integer size) {
			if(!this.members.isEmpty()
				&& this.currentContainerSize <= METADATA_CONTAINER_ITEM_MAX_SIZE
				&& (this.currentContainerSize + size) <= METADATA_CONTAINER_ITEM_MAX_SIZE) {

				Integer lastIndex = this.members.size() == 0 ? 0 : this.members.size() - 1;
				this.currentContainerSize = this.currentContainerSize + size;
				this.members.get(lastIndex).addMember(member);
			}
			else {
				this.currentContainerSize = 0;
				this.members.add(new MetadataTypeWrapper(type, member));
			}
		}
	}

	public class MetadataTypeWrapper {
		public String jobId;
		public String type;
		public List<String> member;

		public MetadataTypeWrapper(String type, String member) {
			this.type = type;
			this.member = new List<String>{member};
		}

		public void addMember(String member) {
			this.member.add(member);
		}
	}

}