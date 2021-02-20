// This file contains your Data Connector logic
section CoMagic;

[DataSource.Kind="CoMagic", Publish="CoMagic.Publish"]
shared CoMagic.Data = Value.ReplaceType(CoMagic.Func, FuncType);

FuncType = type function (
     reportType  as (type text meta [
        Documentation.FieldCaption = "Report type:",
        Documentation.FieldDescription = "Type ""calls"" is available now.",
        Documentation.AllowedValues = { "calls", "chats", "goals", "offline","all","sessions" }
    ]),
    
     token  as (type text meta [
        Documentation.FieldCaption = "Token:",
        Documentation.FieldDescription = "Enter your Comagic token.",
        Documentation.SampleValues = {"dgbg8Ngklkne0nnrbvbq81vvap"}
    ]),

    start as (type text meta [
        Documentation.FieldCaption = "Start date:",
        Documentation.FieldDescription = "Enter the first date of your statistics. You can specify date in YYYY-MM-DD format or use dynamic formats: today, yesterday, 69daysAgo.",
        Documentation.SampleValues = {"2020-02-28"}
    ]),
     end as (type text meta [
        Documentation.FieldCaption = "End date:",
        Documentation.FieldDescription = "Enter the last date of your statistics. You can specify date in YYYY-MM-DD format or use dynamic formats: today, yesterday, 69daysAgo.",
        Documentation.SampleValues = {"yesterday"}
    ])
    )
    as table meta [
        Documentation.Name = "CoMagic.Data Function",
        Documentation.LongDescription = "Created to get data from CoMagic service",
        Documentation.Examples = {
        [
            Description = "Returns a list of records from your CoMagic table",
            Code = "CoMagic.Data(""12345"",""dgbg8Ngklkne0nnrbvbq81vvap"",""2020-02-20"",""yesterday"")",
            Result = "{[Record1],[Record2],[Record3],...}"
        ],
        [
            Description = "Returns a list of records from your CoMagic table",
            Code = "CoMagic.Data(""54321"",""dgbg8Ngklkne0nnrbvbq81vvap"",""69daysAgo"",""today"")",
            Result = "{[Record1],[Record2],[Record3],...}"
        ]
        }
    ];



CoMagic.Func =( reportType as text, token as text, start as text, end as text)=>
let

    fields = 
    if reportType="calls" then fieldsCalls else 
    if reportType="goals" then fieldsGoals else 
    if reportType="chats" then fieldsChats else
    if reportType="all" then fieldsAll else
    if reportType="sessions" then fieldsSessions else
    if reportType="offline" then fieldsOffline else fieldsCalls,
   
    method = 
    if reportType="calls" then "get.calls_report" else
    if reportType="all" then "get.communications_report" else
    if reportType="calls" then "get.calls_report" else 
    if reportType="goals" then "get.goals_report" else 
    if reportType="sessions" then "get.visitor_sessions_report" else
    if reportType="offline" then "get.offline_messages_report" else "get.calls_report",
    
    source = Table.Join(dateTable(dateFunc(start),dateFunc(end),0),"month0",dateTable(dateFunc(start),dateFunc(end),1),"month1"),
    removeMonth = Table.RemoveColumns(source,{"month0", "month1"}),
    callSum = Table.AddColumn(removeMonth, "sum", each getSum([text0],[text1],method,token)),
    errorMessages = callSum[sum],
    calc =  if (try List.Sum(errorMessages) otherwise 0) >0 then 

    let
        sumType = Table.TransformColumnTypes(callSum, {{"sum", Int64.Type}}),
        divide = Table.TransformColumns(sumType, {{"sum", each _ / 5000, type number}}),
        roundDown = Table.TransformColumns(divide,{{"sum", Number.RoundDown, Int64.Type}}),
        offsets = Table.AddColumn(roundDown, "off", each {0..[sum]}),
        expandOffsets = Table.ExpandListColumn(offsets, "off"),
        offsetType = Table.TransformColumnTypes(expandOffsets, {{"off", Int64.Type}}),
        offsetMultiply = Table.TransformColumns(offsetType, {{"off", each _ * 5000, type number}}),
        addData = Table.AddColumn(offsetMultiply, "data", (x)=>  getCoMagic(fields,x[off],x[text0],x[text1],method,token)),
        removeHelp = Table.RemoveColumns(addData,{"off", "text1", "text0", "sum"}),
        expandData = Table.ExpandTableColumn(removeHelp, "data", fields, fields),
        tagContent = Table.AddColumn(expandData, "tag_names_from_tags", (x)=> List.RemoveNulls ({
        try x[tags]{0}[tag_name] otherwise null, try x[tags]{1}[tag_name] otherwise null, try x[tags]{2}[tag_name] otherwise null, try x[tags]{3}[tag_name] otherwise null, try x[tags]{4}[tag_name] otherwise null,
        try x[tags]{5}[tag_name] otherwise null, try x[tags]{6}[tag_name] otherwise null, try x[tags]{7}[tag_name] otherwise null, try x[tags]{8}[tag_name] otherwise null, try x[tags]{9}[tag_name] otherwise null})),
        tagCommas = Table.TransformColumns(tagContent, {"tag_names_from_tags", each Text.Combine(List.Transform(_, Text.From), ", "), type text})
    in  tagCommas 
    else errorMessages{0}
    in calc;


fieldsCalls=
{"start_time","finish_time","communication_number","virtual_phone_number","contact_phone_number","total_duration","visits_count","source","channel","campaign_name","utm_source","utm_medium","utm_campaign","utm_content","utm_term","search_query","search_engine","referrer","referrer_domain","entrance_page","site_domain_name","communication_type","segments","is_lost","direction","attributes","finish_reason","scenario_name","sale_date","sale_cost","tags","visitor_device","visitor_country","visitor_type","visitor_region","visitor_city","cpn_region_name","visitor_custom_properties","visitor_id","visitor_session_id","communication_id","call_api_external_id","scenario_id","call_api_request_id","contact_id","ym_client_id","ua_client_id","cpn_region_id","person_id","site_id","ef_id","ymclid","campaign_id","gclid","yclid","id","openstat_source","openstat_ad","openstat_service","openstat_campaign","postprocess_duration","clean_talk_duration","talk_duration","lost_call_processing_duration","total_wait_duration","wait_duration","visitor_first_campaign_name","visitor_first_campaign_id","visit_other_campaign","scenario_operations","contact_full_name","communication_page_url","is_transfer","last_answered_employee_rating","first_answered_employee_id","first_answered_employee_full_name","last_answered_employee_full_name","last_answered_employee_id","employees"};


fieldsChats= {"date_time","answer_time","communication_number","duration","messages_count","visits_count","channel","campaign_name","utm_source","utm_medium","utm_campaign","utm_content","utm_term","search_query","search_engine","referrer","referrer_domain","entrance_page","site_domain_name","chat_channel_type","chat_channel_name","communication_type","segments","attributes","release_cause","sale_date","sale_cost","tags","visitor_device","visitor_country","visitor_type","visitor_region","visitor_city","visitor_custom_properties","visitor_id","visitor_session_id","communication_id","ym_client_id","ua_client_id","person_id","site_id","ef_id","ymclid","campaign_id","gclid","yclid","id","openstat_source","openstat_ad","openstat_service","openstat_campaign","visitor_first_campaign_name","visitor_first_campaign_id","visit_other_campaign","communication_page_url","is_transfer","initiator","status","employee_raiting","employee_id","employee_messages_count","employee_full_name"};


fieldsGoals=  {"date_time","communication_number","visits_count","source","channel","campaign_name","utm_source","utm_medium","utm_campaign","utm_content","utm_term","search_query","search_engine","referrer","referrer_domain","entrance_page","site_domain_name","communication_type","segments","attributes","sale_date","sale_cost","tags","visitor_device","visitor_country","visitor_type","visitor_region","visitor_city","visitor_custom_properties","visitor_id","visitor_session_id","communication_id","ym_client_id","ua_client_id","person_id","site_id","ef_id","ymclid","campaign_id","gclid","yclid","id","ext_id","openstat_source","openstat_ad","openstat_service","openstat_campaign","visitor_first_campaign_name","visitor_first_campaign_id","visit_other_campaign","communication_page_url","type","name"};

fieldsOffline= {"date_time","process_time","communication_number","visitor_phone_number","visits_count","channel","campaign_name","utm_source","utm_medium","utm_campaign","utm_content","utm_term","search_query","search_engine","referrer","referrer_domain","entrance_page","group_name","site_domain_name","communication_type","form_type","segments","attributes","sale_date","sale_cost","tags","visitor_name","visitor_email","visitor_device","visitor_country","visitor_type","visitor_region","visitor_city","visitor_custom_properties","visitor_id","visitor_session_id","communication_id","group_id","ym_client_id","ua_client_id","person_id","site_id","ef_id","ymclid","campaign_id","gclid","yclid","id","openstat_source","openstat_ad","openstat_service","openstat_campaign","visitor_first_campaign_name","visitor_first_campaign_id","visit_other_campaign","communication_page_url","text","status","employee_id","employee_full_name","employee_answer_message","employee_comment"};


fieldsSessions={"date_time","communications","duration","hits_count","channel","campaign_name","utm_source","utm_medium","utm_campaign","utm_content","utm_term","search_query","search_engine","referrer","referrer_domain","entrance_page","integrated_campaign_data","site_domain_name","segments","engine","visitor_ip_address","visitor_device","visitor_country","visitor_type","visitor_region","visitor_city","visitor_os_version","visitor_browser_name","visitor_browser_version","visitor_custom_properties","visitor_provider","visitor_language","visitor_os_name","visitor_screen","visitor_id","ym_client_id","ua_client_id","site_id","ef_id","ymclid","gclid","yclid","id","cm_id","openstat_source","openstat_ad","openstat_service","openstat_campaign"};


fieldsAll=
{"date_time","communication_number","visits_count","channel","campaign_name","utm_source","utm_medium","utm_campaign","utm_content","utm_term","search_query","search_engine","referrer","referrer_domain","entrance_page","site_domain_name","communication_type","segments","attributes","sale_date","sale_cost","tags","visitor_device","visitor_country","visitor_type","visitor_region","visitor_city","visitor_custom_properties","visitor_id","visitor_session_id","ym_client_id","ua_client_id","person_id","site_id","ef_id","ymclid","campaign_id","gclid","yclid","id","openstat_source","openstat_ad","openstat_service","openstat_campaign","visitor_first_campaign_name","visitor_first_campaign_id","visit_other_campaign","communication_page_url"};




dateFunc= (dat)=>
       if dat = "yesterday" then Date.ToText(Date.AddDays(Date.From(DateTime.LocalNow()) , -1),"yyyy-MM-dd") 
       else if dat = "today" then Date.ToText(Date.From(DateTime.LocalNow()),"yyyy-MM-dd")
       else if (try Number.From(Text.BeforeDelimiter(dat,"daysAgo")) otherwise 0) >0 then Date.ToText(Date.AddDays(Date.From(DateTime.LocalNow()),-1*Number.From(Text.BeforeDelimiter(dat,"daysAgo"))),"yyyy-MM-dd") 
       else dat;



dateTable = (date1, date2, order)=>
let
    listDates= List.Dates(Date.From(date1), Number.From(Date.From(date2)-Date.From(date1))+1, #duration(1,0,0,0) ),
    tableDates = Table.FromList(listDates, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    typeDates = Table.TransformColumnTypes(tableDates, {{"Column1", type date}}),
    sortDates = Table.Sort(typeDates,{{"Column1", order}}),
    monthAdd = Table.AddColumn(sortDates , "month"& Text.From(order), each Date.ToText([Column1],"yyyy-MM")),
    monthType = Table.TransformColumnTypes(monthAdd,{{"month"& Text.From(order), type text}}),
    removeDuplicates = Table.Distinct(monthType , {"month"& Text.From(order)}),
    textAdd = Table.AddColumn(removeDuplicates, "text"& Text.From(order), each (Date.ToText([Column1],"yyyy-MM-dd") )),
    renameDate = Table.RenameColumns(textAdd,{{"Column1", "date"&Text.From(order)}}),
    removeDate = Table.RemoveColumns(renameDate,{"date"& Text.From(order)}),
    textType = Table.TransformColumnTypes(removeDate,{{"text"& Text.From(order), type text}})
in textType;



getCoMagic=(fields,off,date1,date2,met,token)=> 
let
    data = Json.FromValue([jsonrpc="2.0",id=Number.From(Text.From(Number.From(Date.From(date1)))&Text.From(Number.From(Date.From(date2)))&"1"&Text.From(Time.Hour(DateTime.LocalNow()))),
    method=met,
    params=[access_token=token, date_from= date1 & " 00:00:00", date_till=date2 & " 23:59:59",limit=5000,offset=off,
    fields=fields]]),
    web = Function.InvokeAfter(()=> Web.Contents("https://dataapi.CoMagic.ru/v2.0", [ Content = data, ManualStatusHandling = {404, 400}]),#duration(0,0,0,0.4) ),
    json= Json.Document(web),
    getData = json[result][data],
    dataTable = Table.FromList(getData , Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    expand = Table.ExpandRecordColumn(dataTable, "Column1", fields,fields)
in expand;



getSum=(date1,date2,met,token)=>
let
    data = Json.FromValue([jsonrpc="2.0",id=Number.From(Text.From(Number.From(Date.From(date1)))&Text.From(Number.From(Date.From(date2)))&"0"&Text.From(Time.Hour(DateTime.LocalNow())) ),
    method=met,
    params=[access_token=token,date_from=date1&" 00:00:00",date_till=date2&" 23:59:59",limit=5000,offset=0,fields={"id"}]]),
    web = Web.Contents("https://dataapi.CoMagic.ru/v2.0", [ Content = data,  ManualStatusHandling = {404, 400}]),
    json = Json.Document(web),
    result = json[result]?[metadata]?[total_items]?
in if result =null then json[error][message] else result;


CoMagic = [
    TestConnection = (dataSourcePath) => { "CoMagic.Data", Json.Document(dataSourcePath)[reportType],Json.Document(dataSourcePath)[token],Json.Document(dataSourcePath)[start],Json.Document(dataSourcePath)[end]},
    Authentication = [
        
         Implicit = []
   
    ],
    Label = "CoMagic Connection"
];



CoMagic.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { "CoMagic Connector", "CoMagic Help" },
    LearnMoreUrl = "https://www.youtube.com/channel/UCqSLNYLN_3mf6nA1Xf7fu1g/",
    SourceImage = CoMagic.Icons,
    SourceTypeImage = CoMagic.Icons
];



CoMagic.Icons = [
    Icon16 = { Extension.Contents("comagic16.png"), Extension.Contents("comagic20.png"), Extension.Contents("comagic24.png"), Extension.Contents("comagic32.png") },
    Icon32 = { Extension.Contents("comagic32.png"), Extension.Contents("comagic40.png"), Extension.Contents("comagic48.png"), Extension.Contents("comagic64.png") }
];
