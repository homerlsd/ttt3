public without sharing class SlackService {

    public static void sendMessageToSlack(String message, String slack_channel_id) {

        if(!PermissionsUtil.SlackIntegrationEnabled) return;

        if (!ConfigUtil.SLACK_SETTINGS.Slack_Enabled__c ||
            ConfigUtil.SLACK_SETTINGS.Slack_API_Token__c == null ||
            slack_channel_id == null) {
            throw new SlackServiceException('Slack settings are invalid');
        }

        Map<String, Object> payload = new Map<String, Object>{
            'channel' => slack_channel_id,
            'text' => message
        };

        String b = HttpUtils.post(
            ConfigUtil.SLACK_POST_MESSAGE_ENDPOINT,
            JSON.serialize(payload),
            ConfigUtil.SLACK_API_HEADERS,
            200
        );
    }

    public static Boolean isValidChannel(String slackChannelId) {
        Boolean result = false;
        for(SlackService.SlackChannel sc : getChannels()) {
            if(slackChannelId == sc.id) {
                result = true;
                break;
            }
        }
        return result;
    }

    public static List<SlackChannel> getChannels() {
        if (ConfigUtil.SLACK_SETTINGS.Slack_API_Token__c == null) {
            throw new SlackServiceException('Slack Token not found');
        }
        String b = HttpUtils.get(
            ConfigUtil.SLACK_CONVERSATION_LIST_ENDPOINT,
            ConfigUtil.SLACK_API_CONVERSATION_LIST_HEADERS,
            200
        );
        SlackChannelsResponse resp = (SlackChannelsResponse)JSON.deserialize(b, SlackChannelsResponse.class);
        resp.channels.sort();
        return resp.channels;
    }

    public class SlackChannelsResponse {
        public Boolean ok;
        public List<SlackChannel> channels;
    }

    public class SlackChannel implements Comparable {
        public String id;
        public String name;
        public String is_channel;
        public Boolean is_member;
        public Boolean is_private;
        public Boolean is_archived;
        public Integer num_members;

        public Integer compareTo(Object compareTo) {
            SlackChannel compareToEmp = (SlackChannel)compareTo;
            if (name == compareToEmp.name) return 0;
            if (name > compareToEmp.name) return 1;
            return -1;
        }
    }

    public class SlackServiceException extends Exception {}

}