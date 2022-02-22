public with sharing class TestDataGeneratorScheduler implements Schedulable, Database.AllowsCallouts {

	public Enum MODE {
		CHECK_COMPLETE_SETUP_CONNECTED_APP_AND_SEND_EMAIL,
		CEHCK_MONITORING_EVENTS,
		CHECK_TEST_EMAIL_EXCEPTION,
		CEHCK_TEST_PLATFORM_EVENT
	}

	public TestDataGeneratorScheduler.MODE mode;
	public String data;

	public TestDataGeneratorScheduler(TestDataGeneratorScheduler.MODE runMode, String data) {
		this.mode = runMode;
		this.data = data;
	}

	public void execute(SchedulableContext sc) {
		switch on this.mode {
			when CHECK_COMPLETE_SETUP_CONNECTED_APP_AND_SEND_EMAIL {
				TestDataGenerator.startCheckSetupConnectedAppFuture(this.data);
			}
			when CEHCK_MONITORING_EVENTS {
				TestDataGenerator.startCheckMonitoringEventsFuture(this.data);
			}
			when CHECK_TEST_EMAIL_EXCEPTION {
				TestDataGenerator.startCheckTestEmailExceptionLogFuture(this.data);
			}
			when CEHCK_TEST_PLATFORM_EVENT {
				TestDataGenerator.startCheckTestPlatformEventFuture(this.data);
			}
		}
	}

}