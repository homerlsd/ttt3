public with sharing class GitHubCommitBatch3 implements Database.batchable<MetadataTypeWrapper>,Database.Stateful, Database.AllowsCallouts,Database.RaisesPlatformEvents {

	public Enum BATCH_MODE {
		SUBMIT_RETRIEVE_REQUEST,
		PROCESS_METADATA_ITEMS
	}
	private BATCH_MODE currentMode;
	private String refPath;
	private List<MetadataTypeWrapper> incompletedPackageItems = new List<MetadataTypeWrapper>();

	public GitHubCommitBatch3() {
		this(BATCH_MODE.SUBMIT_RETRIEVE_REQUEST);
	}

	public GitHubCommitBatch3(BATCH_MODE batchMode) {
		this.currentMode = batchMode;
	}

	public GitHubCommitBatch3(BATCH_MODE batchMode, List<MetadataTypeWrapper> incompletedPackageItems) {
		this.currentMode = batchMode;
		this.incompletedPackageItems = incompletedPackageItems;
	}

	public Iterable<MetadataTypeWrapper> start(Database.BatchableContext bc) {
		MetadataTypeIterable iterable;

		if(this.currentMode == BATCH_MODE.SUBMIT_RETRIEVE_REQUEST) {
			iterable = new MetadataTypeIterable(getDefaultMetadataTypeMembers());
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
//				List<MetadataTypeWrapper> retrieveItems = GitHubUtils.createSubmitRetrieveRequest(scopeItems.get(0));
//				if(!retrieveItems.isEmpty()) {
//					putMetadataPackageItemsToCache(retrieveItems);
//				}
			}
			when PROCESS_METADATA_ITEMS {
				List<MetadataTypeWrapper> scopeItems = (List<MetadataTypeWrapper>)scope;
				//List<GitHubUtils.SourceMetadataFile> files = GitHubUtils.processMetadataItems(scopeItems.get(0));
//				if(files.isEmpty()) {
//					this.incompletedPackageItems.add(scopeItems.get(0));
//				}
//				else {
//					this.refPath = GitHubUtils.makeCommit(files, this.refPath);
//				}
			}
		}
	}

	public void finish(Database.BatchableContext BC) {
		switch on this.currentMode {
			when SUBMIT_RETRIEVE_REQUEST {
				Database.executeBatch(new GitHubCommitBatch3(BATCH_MODE.PROCESS_METADATA_ITEMS), 1);
			}
			when PROCESS_METADATA_ITEMS {
				if(!this.incompletedPackageItems.isEmpty()) {
					Database.executeBatch(new GitHubCommitBatch3(BATCH_MODE.PROCESS_METADATA_ITEMS, this.incompletedPackageItems), 1);
				}
				else {
					GitHubUtils.gitCreatePullRequest();
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

	public static List<MetadataTypeWrapper> getDefaultMetadataTypeMembers() {
		List<MetadataTypeWrapper> result = new List<MetadataTypeWrapper>();
		result.add(new MetadataTypeWrapper('CustomObject', '*'));
		for(ApexClass apexClass : [SELECT NamespacePrefix, Name FROM ApexClass]) {
			if(apexClass.Name == 'GitHubUtils'
				|| apexClass.Name == 'GitHubCommitBatch'
				|| apexClass.Name == 'GitHubCommitBatch2'
				|| apexClass.Name == 'GitHubCommitBatch3') continue;

			result.add(new MetadataTypeWrapper('ApexClass', apexClass.Name));

		}
		for(ApexTrigger apexTrigger : [SELECT NamespacePrefix, Name FROM ApexTrigger]) {
			result.add(new MetadataTypeWrapper('ApexTrigger', apexTrigger.Name));
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

	public class MetadataTypeWrapper {
		public String jobId;
		public String type;
		public String member;

		public MetadataTypeWrapper(String type, String member) {
			this.type = type;
			this.member = member;
		}
	}
}