class AsyncWorldApi < ActionWebService::API::Base
  api_method :execute_via_ws,
             :expects => [{:request => WorldRequest}],
             :returns => [:bool]
end
