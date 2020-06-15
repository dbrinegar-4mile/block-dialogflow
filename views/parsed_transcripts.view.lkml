view: parsed_transcripts {
  derived_table: {
    persist_for: "2 hours"
    #
    #
    sql:
    CREATE TEMP FUNCTION proto2json(prototext STRING, arrayKeys STRING)
      RETURNS STRING
      LANGUAGE js AS """

        /*TODO: maybe escape existing # in case it shows up in an unquoted key */

        /* Replace all strings with opaque reference to avoid matching inside them */
        var strings = []
        prototext = prototext.replace(
          /"([^"\\\\]*(\\\\.[^"\\\\]*)*)"/g,
          function(match){
            strings.push(match);
            return '#'+(strings.length-1)+' '
            }
          )

        /*Strip the leading type declaration*/
        prototext = prototext.replace(/^[A-za-z0-0 _]+\\s*:/,'');
        /* Add a colon between object key and abject */
        prototext = prototext.replace(/([a-zA-Z0-9_]+)\\s*\\{/g, function(match,m1){return m1+': {';});
        /* Add quotes around keys */
        prototext = prototext.replace(/([a-zA-Z0-9_]+):/g, function(match,m1){return '"'+m1+'" :';});
        /* Add commas between values */
        prototext = prototext.replace(/([0-9"}])\\s*\\n\\s*"/g, function(match,m1){return m1+' ,\\n "';});

        /* If array keys, take matching keys and prep them to not collapse */
        if(arrayKeys){
          if(arrayKeys && !arrayKeys.match(/^[A-Za-z0-9_]+(,[A-Za-z0-9_]+)*$/)){
            throw "Only [A-Za-z0-9_] array keys are currently supported, delimited by commas"
          }
          arrayKeys = arrayKeys.split(',')
          var arrayKeyRegex = new RegExp('"('+arrayKeys.join('|')+')"','g')
          var counter=0
          prototext = prototext.replace(arrayKeyRegex,function(match,key){
            counter++
            return '"'+key+'#'+counter+'"'
            })
          }

        /* Replace string references with their original values*/
        prototext = prototext.replace(
          /#(\\d+) /g,
          function(match,m1){
            return strings[parseInt(m1)]
            }
          )
        var jsonish = '{'+prototext+'}'

        if(!arrayKeys){return jsonish}
        var obj
        try{
          /* Parse jsonish, but replace all key#n entries with arrays*/
          obj = JSON.parse(jsonish, function(key,objValue){
            if(typeof objValue !== "object"){return objValue}
            var returnValue = {}
            var entries = Object.entries(objValue)
            /* Entries should already come out in lexicographical order, but if not we could sort here */
            for(let [entryKey,entryVal] of entries){
              let [groupKey,n] = entryKey.split('#')
              if(n===undefined){
                returnValue[entryKey] = entryVal
                }
              else{
                returnValue[groupKey] = (returnValue[groupKey]||[]).concat(entryVal)
              }
            }
            return returnValue
          })
        }
        catch(e){return "JSON Error! "+e+"\\n"+jsonish}
        return JSON.stringify(obj,undefined,1)
      """;
    SELECT
      textPayload as textPayload,
      regexp_extract(textPayload, r'webhook_used: .*') as webhook_used,
      regexp_extract(textPayload, r'webhook_for_slot_filling_used: .*') as webhook_for_slot_filling_used,
      regexp_extract(textPayload, r'string_value: .*') as string_value,
      regexp_extract(textPayload, r'speech: .*') as speech,
      regexp_extract(textPayload, r'source: .*') as source,
      regexp_extract(textPayload, r'session_id: .*') as session_id,
      regexp_extract(textPayload, r'score: .*') as score,
      regexp_extract(textPayload, r'resolved_query: .*') as resolved_query
      ,regexp_extract(textPayload, r'responseId": ".*') as response_id,
      regexp_extract(textPayload, r'queryText": ".*') as queryText,
      regexp_extract(textPayload, r'name": ".*') as name,
      regexp_extract(textPayload, r'intent_name: .*') as intent_name,
      regexp_extract(textPayload, r'intent_id: .*') as intent_id,
      regexp_extract(textPayload, r'code: .*') as code
      ,regexp_extract(textPayload, r'error_type: .*') as error_type
      ,regexp_extract(textPayload, r'is_fallback_intent: .*') as is_fallback_intent
      ,regexp_extract(textPayload, r'lang: .*') as lang
      ,regexp_extract(textPayload, r'timestamp: .*') as receiveTimestamp,

      regexp_extract(textPayload, r'id: .*') as id,
      regexp_extract(textPayload, r'timestamp: .*') as timestamp,
      regexp_extract(textPayload, r'source: .*') as result_source
      -- ,regexp_extract(textPayload, r'insertId: .*') as insertId
      -- ,regexp_extract(textPayload, r'logName: .*') as logName
      -- regexp_extract(textPayload, r'trace: .*') as trace,
      , proto2json(textPayload,"messages,fields") as payload_as_json
      FROM `covid-19-rrva-khwrml.rrva.transcripts`
      limit 1000
       ;;
  }






  dimension: text_payload {
    type: string
    sql: ${TABLE}.textPayload ;;
  }

  measure: count {
    type: count
    drill_fields: [detail*]
  }

  dimension: payload_type {
    type: string
    sql: split(${text_payload}, ':')[OFFSET(0)];;
  }

  dimension: webhook_used {
    type: string
    sql:replace(ltrim( ${TABLE}.webhook_used, 'webhook_used:'),"\"","") ;;

  }

  dimension: webhook_for_slot_filling_used {
    type: string
    sql:replace(ltrim( ${TABLE}.webhook_for_slot_filling_used, 'webhook_for_slot_filling_used:'),"\"","") ;;

  }

  dimension: string_value {
    type: string
    sql:replace(ltrim( ${TABLE}.string_value, 'string_value: '),"\"","") ;;

  }

  dimension: speech {
    type: string
    sql:replace(ltrim( ${TABLE}.speech, 'speech: '),"\"","") ;;
  }

  dimension: source {
    type: string
    sql:replace(ltrim( ${TABLE}.source, 'source: '),"\"","") ;;

  }

  dimension: session_id {
    type: string
    sql:replace(ltrim( ${TABLE}.session_id, 'session_id: '),"\"","") ;;

  }

  dimension: score {
    type: string
    sql:replace(ltrim( ${TABLE}.score, 'score: '),"\"","") ;;

  }

  dimension: resolved_query {
    type: string
    sql:replace(ltrim( ${TABLE}.resolved_query, 'resolved_query: '),"\"","") ;;

  }

  dimension: response_id {
    type: string
    sql:replace(ltrim( ${TABLE}.response_id, 'response_id: '),"\"","") ;;

  }

  dimension: query_text {
    type: string
    sql:replace(ltrim( ${TABLE}.queryText, 'queryText: '),"\"","") ;;

  }
  dimension: payload_as_json {
    html: <div style="white-space:pre;max-width:640px;overflow:hidden">{{value}}</div> ;;
  }
  dimension: extract_maybe_json {
    sql: JSON_EXTRACT(${payload_as_json}, '$.result.source') ;;
    # or if you just want the value, rather than the JSON
    # sql: JSON_EXTRACT_SCALAR(${payload_as_json}, '$.result.source') ;;
  }

  dimension: name {
    type: string
    sql:replace(ltrim( ${TABLE}.name, 'name: '),"\"","") ;;

  }

  dimension: intent_name {
    type: string
    sql: replace(ltrim( ${TABLE}.intent_name, 'intent_name:'),"\"","");;
  }

  dimension: intent_category {
    type: string
    sql: split(${intent_name}, '.')[OFFSET(0)];;
  }

  dimension: intent_id {
    type: string
    sql: replace(ltrim( ${TABLE}.intent_id, 'intent_id:'),"\"","");;
  }

  dimension: code {
    type: number
    sql: cast(ltrim( ${TABLE}.code, 'code:') as int64);;
  }

  dimension: error_type {
    type: string
    sql:replace(ltrim( ${TABLE}.error_type, 'error_type:'),"\"","") ;;
  }

  dimension: is_fallback_intent {
    type: string
    sql:replace(ltrim( ${TABLE}.is_fallback_intent, 'is_fallback_intent:'),"\"","") ;;

  }

  dimension: lang {
    type: string
    sql: replace(ltrim( ${TABLE}.lang, 'lang:'),"\"","");;
  }

  dimension_group: receive_timestamp {
    type: time
    sql: cast(${TABLE}.receiveTimestamp as timestamp) ;;
  }

  dimension: id {
    type: string
    sql: ${TABLE}.id ;;
  }

  dimension_group: timestamp {
    type: time
    sql: cast(trim(replace(ltrim( ${TABLE}.timestamp, 'timestamp:'),"\"","")) as timestamp);;
  }

  dimension: result_source {
    type: string
    sql: ${TABLE}.result_source ;;
  }


  #### Missing Dimensions ####

  dimension: trace {
    view_label: "Missing"
    type: string
  }

  dimension: caller_id {
    view_label: "Missing"
  }



  measure: count_distinct_trace {
    type: count_distinct
    sql: ${trace} ;;
  }

  ##Below are Calculations From "Metrics to Measure" Google Doc

  measure: total_chat_sessions {
    type: count_distinct
    sql: ${session_id} ;;
    drill_fields: [session_id]
  }

  measure: total_telephone_users {
    type: count_distinct
    sql: ${caller_id} ;;
  }

  measure: total_intents {
    type: count_distinct
    sql: ${intent_name} ;;
  }

  measure: total_fallbacks {
    type: count
    filters:  {
      field: is_fallback_intent
      value: "true"
    }
  }

  measure: total_successful_intents {
    type: count
    filters:  {
      field: is_fallback_intent
      value: "false"
    }
  }

  measure: successful_intent_rate {
    type: number
    value_format_name: percent_2
    sql: ${total_successful_intents}/NULLIF(${count},0) ;;
  }

  measure: fallback_rate {
    type: number
    value_format_name: percent_2
    sql: ${total_fallbacks}/NULLIF(${count},0) ;;
  }

  dimension: area_code {
    view_label: "Missing"
    type: string
    sql: SUBSTR(${caller_id},2,3) ;;
  }

  measure: max_timestamp {
    view_label: "Missing"
    type: date_time
    sql: MAX(${receive_timestamp_raw}) ;;
  }

  measure: min_timestamp {
    view_label: "Missing"
    type: date_time
    sql: MIN(${receive_timestamp_raw}) ;;
  }

  set: detail {
    fields: [
      webhook_used,
      webhook_for_slot_filling_used,
      string_value,
      speech,
      source,
      session_id,
      score,
      resolved_query,
      response_id,
      query_text,
      name,
      intent_name,
      intent_id,
      code,
      error_type,
      is_fallback_intent,
      lang    ]
  }
}
