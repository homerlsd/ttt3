global with sharing class HttpResponseWrapper {

    private final HttpResponse response;

    /**
	 * Create a new {@code HttpResponse} wrapping the given response object.
	 * @param response -- the response object to be wrapped.
	 */
    global HttpResponseWrapper(HttpResponse response) {
        this.response = response;
    }

    /**
	 * @return the wrapped response.
	 */
    public HttpResponse getResponse() {
        return response;
    }

    /**
	 * @return headerKeys of the wrapped response.
	 */
    public List<String> getHeaderKeys() {
        return response.getHeaderKeys();
    }

    /**
     * @param key -- the key of the header.
	 * @return header of the wrapped response.
	 */
    public String getHeader(String key) {
        return response.getHeader(key);
    }

    /**
	 * @return headers of the wrapped response.
	 */
    public Map<String, String> getHeaders() {
        Map<String, String> mapHeaders = new Map<String, String>();
        for (String key : response.getHeaderKeys()) {
            mapHeaders.put(key, getHeader(key));
        }
        return mapHeaders;
    }

    /**
	 * @return body of the wrapped response.
	 */
    public String getBody() {
        return response.getBody();
    }

    /**
	 * @return bodyAsBlob of the wrapped response.
	 */
    public Blob getBodyAsBlob() {
        return response.getBodyAsBlob();
    }

    /**
	 * @return status of the wrapped response.
	 */
    public String getStatus() {
        return response.getStatus();
    }

    /**
	 * @return statusCode of the wrapped response.
	 */
    public Integer getStatusCode() {
        return response.getStatusCode();
    }

    /**
	 * @return format response of the wrapped response.
	 */
    global Map<String, Object> formatResponse() {
        if (response == null) return null;
        return new Map<String, Object>{
                'headerKeys' => getHeaderKeys(),
                'headers' => getHeaders(),
                'body' => getBody(),
                'bodyAsBlob' => getBodyAsBlob(),
                'status' => getStatus(),
                'statusCode' => getStatusCode()
        };
    }

}