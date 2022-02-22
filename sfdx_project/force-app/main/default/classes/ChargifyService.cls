public with sharing class ChargifyService {

	public class HttpChargifyServiceException extends Exception {}

	public static final String CHARGIFY_API_TOKNE = 'Gi2U0FBz5XkibLLzIybBS6D9TUIDIcuKEzzoRy3i2Y';
	public static final String CHARGIFY_SITE_DOMAIN = 'pharos-ai-clone';
	public static String GET_SUBSCRIPTION_BY_ID_PATTERN = 'https://{0}.chargify.com/subscriptions/{1}.json';
	public static String GET_SUBSCRIPTION_CUSTOM_FIELDS_PATTERN = 'https://{0}.chargify.com/subscriptions/{1}/metadata.json';

	public static final String HTTP_METHOD_GET = 'GET';
	public static final Integer HTTP_TIMEOUT_LIMIT = 120000;

	public static final String CHARGIFY_WEBHOOK_PARAMETER_EVENT = 'event';
	public static final String EVENT_SIGNUP_SUCCESS_KEY_SUBSCRIPTION_ID = 'payload[subscription][id]';

	public static final String SUBSCRIPTION_CUSTOM_FIELD_ORG_ID = 'Organization Id';
	public static final String SUBSCRIPTION_STATE_ACTIVE = 'active';


	public static void handleChargifyEvent(Map<String, String> requestParams) {
		if(isValidWebhookEvent(requestParams)) {
			String webHookEventName = getWebHookEventName(requestParams);
			switch on webHookEventName {
				// new customer, end of payment, created subscription
				when 'signup_success' {
					activateNewCustomerPackageLicense(requestParams);
				}
			}
		}
	}

	public static Boolean isValidWebhookEvent(Map<String, String> requestParams) {
		return (requestParams != null && requestParams.containsKey(CHARGIFY_WEBHOOK_PARAMETER_EVENT));
	}

	public static String getWebHookEventName(Map<String, String> requestParams) {
		return requestParams.get(CHARGIFY_WEBHOOK_PARAMETER_EVENT);
	}

	public static void activateNewCustomerPackageLicense(Map<String, String> requestParams) {
		String subscriptionId = requestParams.get(EVENT_SIGNUP_SUCCESS_KEY_SUBSCRIPTION_ID);
		if(String.isNotBlank(subscriptionId)) {

			Subscription newSubscription = getSubscriptionById(subscriptionId);
			if(newSubscription != null && newSubscription.state == SUBSCRIPTION_STATE_ACTIVE) {

				String organisationId = getSubscriptionOrganisationId(subscriptionId);
				if(String.isNotBlank(organisationId)) {
					// activate salesforce org
				}
			}
		}
	}

	public static String getSubscriptionOrganisationId(String subscriptionId) {
		String result;

		List<CustomField> customFields = getSubscriptionCustomFields(subscriptionId);
		for(CustomField cf : customFields) {
			if(SUBSCRIPTION_CUSTOM_FIELD_ORG_ID == cf.name) {
				result = cf.value;
				break;
			}
		}

		return result;
	}

	public static List<CustomField> getSubscriptionCustomFields(String subscriptionId) {
		List<CustomField> result;

		try {
			Map<String, String> headers = getHeadersAuthorization('Basic ' + EncodingUtil.base64Encode(Blob.valueOf(CHARGIFY_API_TOKNE)));
			String endpoint = String.format(GET_SUBSCRIPTION_CUSTOM_FIELDS_PATTERN, new List<String>{CHARGIFY_SITE_DOMAIN, subscriptionId});

			String b = doGet(
				endpoint ,
				headers,
				200
			);
			system.debug('---getSubscriptionCustomFields--'+b);

			Metadata metadata = (Metadata)JSON.deserialize(b, Metadata.class);
			if(metadata != null && metadata.metadata != null && !metadata.metadata.isEmpty()) {
				result = metadata.metadata;
			}
		}
		catch(Exception e){}

		return result;
	}

	public static Subscription getSubscriptionById(String subscriptionId) {
		Subscription result;

		try {
			Map<String, String> headers = getHeadersContentTypeJSON();
			headers.putAll(getHeadersAuthorization('Basic ' + EncodingUtil.base64Encode(Blob.valueOf(CHARGIFY_API_TOKNE))));
			String endpoint = String.format(GET_SUBSCRIPTION_BY_ID_PATTERN, new List<String>{CHARGIFY_SITE_DOMAIN, subscriptionId});

			String b = doGet(
				endpoint ,
				headers,
				200
			);
			system.debug('---getSubscriptionById--'+b);

			SubscriptionObject subscriptionObject = (SubscriptionObject)JSON.deserialize(b, SubscriptionObject.class);
			result = SubscriptionObject.subscription;
		}
		catch(Exception e){}

		return result;
	}

	public static final String HTTP_CONTENT_TYPE_JSON = 'application/json';

	public static Map<String, String> getHeadersContentType(String typeValue) {
		return new Map<String, String>{
			'Content-Type' => typeValue
		};
	}
	public static Map<String, String> getHeadersContentTypeJSON() {
		return getHeadersContentType(HTTP_CONTENT_TYPE_JSON);
	}

	public static Map<String, String> getHeadersAuthorization(String authValue) {
		return new Map<String, String>{
			'Authorization' => authValue
		};
	}

	public static String doGet(String endpoint, Map<String, String> headers, Integer expectedResponceCode) {
		String result;

		HTTPRequest req = new HTTPRequest();
		req.setEndpoint(endpoint);
		req.setMethod(HTTP_METHOD_GET);
		req.setTimeout(HTTP_TIMEOUT_LIMIT);
		if (headers != null) {
			for (String key : headers.keySet()) {
				req.setHeader(key, headers.get(key));
			}
		}
		Http h = new Http();
		HttpResponse res = h.send(req);

		if(res.getStatusCode() == expectedResponceCode) {
			return res.getBody();
		}
		else {
			throw new HttpChargifyServiceException(res.getStatusCode() + ': ' + res.getBody());
		}
	}

	public class Metadata {

		public Integer total_count;
		public Integer current_page;
		public Integer total_pages;
		public Integer per_page;
		public List<CustomField> metadata;

		public Metadata(){}
	}

	public class CustomField {

		public Integer id;
		public String value;
		public Integer resource_id;
		public String deleted_at;
		public String name;

		public CustomField(){}
	}


	public class SubscriptionObject {
		public Subscription subscription;
		public SubscriptionObject(){}
	}

	public class Subscription {

		public Long id;
		public String state;
		public String trial_started_at;
		public String trial_ended_at;
		public String activated_at;
		public String created_at;
		public String updated_at;
		public String expires_at;
		public Integer balance_in_cents;
		public String current_period_ends_at;
		public String next_assessment_at;
		public String canceled_at;
		public String cancellation_message;
		public String next_product_id;
		public String next_product_handle;
		public String cancel_at_end_of_period;
		public String payment_collection_method;
		public String snap_day;
		public String cancellation_method;
		public String current_period_started_at;
		public String previous_state;
		public Integer signup_payment_id;
		public String signup_revenue;
		public String payment_type;
		public Integer payer_id;
		//public String currency;

		public Customer customer;
		public Product product;
		public ProductFamily product_family;

		public Subscription() {}
	}

	public class CreditCard {

		public Integer id;
		public String first_name;
		public String last_name;
		public String masked_card_number;
		public String card_type;
		public Integer expiration_month;
		public Integer expiration_year;
		public Integer customer_id;
		public String current_vault;
		public String vault_token;
		public String billing_address;
		public String billing_city;
		public String billing_state;
		public String billing_zip;
		public String billing_country;
		public String customer_vault_token;
		public String billing_address_2;
		public String payment_type;
		public Boolean disabled;
		public Integer site_gateway_setting_id;

		public CreditCard(){}
	}

	public class ProductFamily {

		public Integer id;
		public String name;
		public String description;
		public String handle;
		public String accounting_code;
		public String created_at;
		public String updated_at;

		public ProductFamily() {}
	}

	public class Product {

		public Integer id;
		public String name;
		public String handle;
		public String description;
		public String accounting_code;
		public Boolean request_credit_card;
		public String expiration_interval;
		public String expiration_interval_unit;
		public String created_at;
		public String updated_at;
		public Integer price_in_cents;
		public Integer interval;
		public String interval_unit;
		public Integer initial_charge_in_cents;
		public Integer trial_price_in_cents;
		public String trial_interval;
		public String trial_interval_unit;
		public String archived_at;
		public Boolean require_credit_card;
		public String return_params;
		public Boolean taxable;
		public String update_return_url;
		public String tax_code;
		public Boolean initial_charge_after_trial;
		public Integer version_number;
		public String update_return_params;
		public Integer default_product_price_point_id;
		public Boolean request_billing_address;
		public Boolean require_billing_address;
		public Boolean require_shipping_address;
		public Integer product_price_point_id;
		public String product_price_point_name;
		public String product_price_point_handle;

		public Product(){}
	}

	public class Customer {

		public Integer id;
		public String first_name;
		public String last_name;
		public String organization;
		public String email;
		public DateTime created_at;
		public DateTime updated_at;
		public String address;
		public String address_2;
		public String city;
		public String state;
		public String state_name;
		public String zip;
		public String country;
		public String country_name;
		public String phone;
		public DateTime portal_invite_last_sent_at;
		public DateTime portal_invite_last_accepted_at;
		public Boolean verified;
		public DateTime portal_customer_created_at;
		public String vat_number;
		public String cc_emails;
		public String tax_exempt;
		public String parent_id;
		public String locale;

		public Customer(){}
	}
}