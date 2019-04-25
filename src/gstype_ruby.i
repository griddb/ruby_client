/*
    Copyright (c) 2017 TOSHIBA Digital Solutions Corporation.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

%{
#include <limits>
%}

#define UTC_TIMESTAMP_MAX 253402300799999
#define INTEGER_MAX 2147483647 //max rows for query

%include <attribute.i>;

//Support keyword arguments
%feature("autodoc", "0");

//Read only attribute Container::type
%attribute(griddb::Container, int, type, get_type);
//Read only attribute GSException::is_timeout
%attribute(griddb::GSException, bool, is_timeout, is_timeout);
//Read only attribute PartitionController::partition_count
%attribute(griddb::PartitionController, int, partition_count, get_partition_count);
//Read only attribute RowKeyPredicate::type
%attribute(griddb::RowKeyPredicate, GSType, key_type, get_key_type);
//Read only attribute RowSet::size
%attribute(griddb::RowSet, int32_t, size, size);
//Read only attribute RowSet::type
%attribute(griddb::RowSet, GSRowSetType, type, type);
//Read only attribute Store::partition_info
%attribute(griddb::Store, griddb::PartitionController*, partition_info, partition_info);
//Read and write attribute ContainerInfo::name
%attribute(griddb::ContainerInfo, GSChar*, name, get_name, set_name);
//Read and write attribute ContainerInfo::type
%attribute(griddb::ContainerInfo, int, type, get_type, set_type);
//Read and write attribute ContainerInfo::row_key
%attribute(griddb::ContainerInfo, bool, row_key, get_row_key_assigned, set_row_key_assigned);
//Read and write attribute ContainerInfo::expiration
%attribute(griddb::ContainerInfo, griddb::ExpirationInfo*, expiration, get_expiration_info, set_expiration_info);
//Read only attribute ContainerInfo::column_info_list
%attributeval(griddb::ContainerInfo, ColumnInfoList, column_info_list, get_column_info_list, set_column_info_list);
//Read only attribute ExpirationInfo::time
%attribute(griddb::ExpirationInfo, int, time, get_time, set_time);
//Read and write attribute ExpirationInfo::unit
%attribute(griddb::ExpirationInfo, GSTimeUnit, unit, get_time_unit, set_time_unit);
//Read and write attribute ExpirationInfo::division_count
%attribute(griddb::ExpirationInfo, int, division_count, get_division_count, set_division_count);

%fragment("convertTimestampToObject", "header",fragment=SWIG_From_frag(double)) {
static VALUE convertTimestampToObject(GSTimestamp* timestamp, bool timestampToFloat = true) {

    if (timestampToFloat) {
        return SWIG_From_double(((double)(*timestamp)) / 1000);
    } else {
        time_t sec = (*timestamp)/1000;
        long milli_sec = (*timestamp)%1000;
        VALUE mDate = rb_time_new(sec, milli_sec*1000);
        return mDate;
    }
}
}

/**
 * Support convert type from object to Bool. input in target language can be :
 * integer or boolean
 */
%fragment("convertObjectToBool", "header") {
static bool convertObjectToBool(VALUE value, GSBool* boolValPtr) {
    if (rb_type(value) == T_FIXNUM) {
        //input can be integer
        int64_t longVal;
        longVal = NUM2LONG(value);
        *boolValPtr = ((longVal != 0) ? GS_TRUE : GS_FALSE);
    } else {
        //input is boolean
        if (rb_type(value) == T_TRUE) {
            *boolValPtr = true;
        } else if (rb_type(value) == T_FALSE) {
            *boolValPtr = false;
        } else {
            return false;
        }
    }
    return true;
}
}
/**
 * Support convert type from object to Float. input in target language can be :
 * float or integer
 */
%fragment("convertObjectToFloat", "header") {
static bool convertObjectToFloat(VALUE value, float* floatValPtr) {
    if (rb_type(value) == T_FIXNUM) {
        //input can be integer
        int64_t longVal;
        longVal = NUM2LONG(value);
        *floatValPtr = (float)longVal;
        return true;
    } else if (rb_type(value) == T_FLOAT) {
        double doubleVal;
        doubleVal = NUM2DBL(value);
        if (doubleVal > std::numeric_limits<float>::max() ||
            doubleVal < -1 * std::numeric_limits<float>::max()) {
            return false;
        }
        *floatValPtr = (float)(doubleVal);
         return true;
    } else {
        return false;
    }
}
}
/**
 * Support convert type from object to Float. input in target language can be :
 * float or integer
 */
%fragment("convertObjectToDouble", "header") {
static bool convertObjectToDouble(VALUE value, double* doubleValPtr) {
    if (rb_type(value) == T_FIXNUM) {
        //input can be integer
        int64_t longVal;
        longVal = NUM2LONG(value);
        *doubleValPtr = (double)longVal;
        return true;
    } else if (rb_type(value) == T_FLOAT) {
        double doubleVal;
        doubleVal = NUM2DBL(value);
        *doubleValPtr = (double)(doubleVal);
         return true;
    } else {
        return false;
    }
}
}
/**
 * Support convert type from object to GSTimestamp: input in target language can be :
 * datetime object, string or float
 */
%fragment("convertObjectToGSTimestamp", "header", fragment = "convertObjectToFloat") {
static bool convertObjectToGSTimestamp(VALUE value, GSTimestamp* timestamp) {
    if (rb_type(value) == T_DATA) {
        *timestamp = 1000 * NUM2DBL(rb_funcall(value, rb_intern("to_f"), 0, NULL));
        if (*timestamp > UTC_TIMESTAMP_MAX) {
            return false;
        }
    } else if (rb_type(value) == T_STRING) {
        // Input is datetime string: ex 1970-01-01T00:00:00.000Z
        char *mStr = StringValuePtr(value);
        GSBool retConvertTimestamp = gsParseTime(mStr, timestamp);
        if (retConvertTimestamp == GS_FALSE) {
            return false;
        }
    } else if (rb_type(value) == T_FLOAT) {
        // Input is VALUE utc timestamp
        double tmpValue;
        tmpValue = NUM2DBL(value) * 1000;
        if (tmpValue > UTC_TIMESTAMP_MAX) {
            return false;
        }
        *timestamp = (int64_t)tmpValue;
    } else if (rb_type(value) == T_FIXNUM) {
        int64_t utcTimestamp = NUM2LONG(value) * 1000;
        if (utcTimestamp > UTC_TIMESTAMP_MAX) {
            return false;
        }
        *timestamp = utcTimestamp;
    } else {
        // Invalid input
        return false;
    }
    return true;
}
}
/**
 * Support convert type from object to Blob. input in target language can be :
 * byte array or string
 * Need to free data.
 */
%fragment("convertObjectToBlob", "header") {
static bool convertObjectToBlob(VALUE value, size_t* size, void** data) {
    GSChar* blobData;
    int res;
    if (rb_type(value) == T_STRING) {
        char *mStr = StringValuePtr(value);
        *size = strlen(mStr) + 1;
        char *tmpStr = new (nothrow) char[*size]();
        if (tmpStr == NULL) {
            return false;
        }
        memcpy(tmpStr, mStr, *size);
        *data = tmpStr;
        return true;
    } else {
        return false;
    }
}
}
/*
 * Support create GSValue value before use gsSetRowFieldGeneral
 */
%fragment("convertToGSValue", header, fragment="SWIG_AsCharPtrAndSize") {
static bool convertToGSValue(VALUE value, GSType type, GSValue *fieldValue) {
    GSBool vbool;
    switch (type) {
        case GS_TYPE_STRING: {
            if (rb_type(value) != T_STRING) {
                return false;
            }
            char* strVal = StringValuePtr(value);
            if (strVal) {
                fieldValue->asString = strdup(strVal);
                if (!fieldValue->asString) {
                    return false;
                }
            } else {
                return false;
            }
            break;
        }
        case GS_TYPE_BOOL: {
            vbool = convertObjectToBool(value, &fieldValue->asBool);
            if (!vbool) {
                return false;
            }
            break;
        }
        case GS_TYPE_BYTE: {
            int64_t longVal;
            if (rb_type(value) != T_FIXNUM) {
                return false;
            }
            longVal = NUM2LONG(value);
            if (longVal < std::numeric_limits<int8_t>::min() ||
                longVal > std::numeric_limits<int8_t>::max()) {
                return false;
            }
            fieldValue->asByte = (int8_t)longVal;
            break;
        }
        case GS_TYPE_SHORT: {
            int64_t longVal;
            if (rb_type(value) != T_FIXNUM) {
                return false;
            }
            longVal = NUM2LONG(value);
            if (longVal < std::numeric_limits<int16_t>::min() ||
                longVal > std::numeric_limits<int16_t>::max()) {
                return false;
            }
            fieldValue->asShort = (int16_t)longVal;
            break;
        }
        case GS_TYPE_INTEGER:
            int64_t longVal;
            if (rb_type(value) != T_FIXNUM) {
                return false;
            }
            longVal = NUM2LONG(value);
            if (longVal < std::numeric_limits<int32_t>::min() ||
                longVal > std::numeric_limits<int32_t>::max()) {
                return false;
            }
            fieldValue->asInteger = (int16_t)longVal;
            break;
        case GS_TYPE_LONG: {
            int64_t longVal;
            if (rb_type(value) != T_FIXNUM && rb_type(value) != T_BIGNUM) {
                return false;
            }
            longVal = NUM2LONG(value);
            fieldValue->asLong = longVal;
            break;
        }
        case GS_TYPE_FLOAT: {
            vbool = convertObjectToFloat(value, &(fieldValue->asFloat));
            if (!vbool) {
                return false;
            }
            break;
        }
        case GS_TYPE_DOUBLE: {
            vbool = convertObjectToDouble(value, &(fieldValue->asDouble));
            if (!vbool) {
                return false;
            }
            break;
        }
        case GS_TYPE_TIMESTAMP: {
            vbool = convertObjectToGSTimestamp(value, &(fieldValue->asTimestamp));
            if (!vbool) {
                return false;
            }
            break;
        }
        case GS_TYPE_GEOMETRY: {
            if (rb_type(value) != T_STRING) {
                return false;
            }
            char* geometryVal = StringValuePtr(value);
            if (geometryVal) {
                fieldValue->asGeometry = strdup(geometryVal);
                if (!fieldValue->asGeometry) {
                    return false;
                }
            } else {
                return false;
            }
            break;
        }
        case GS_TYPE_BLOB: {
            fieldValue->asBlob = {0};
            GSBlob *blobVal = &(fieldValue->asBlob);
            vbool = convertObjectToBlob(value, &blobVal->size, (void**) &blobVal->data);
            if (!vbool) {
                return false;
            }
            break;
        }
        case GS_TYPE_STRING_ARRAY:
        case GS_TYPE_BOOL_ARRAY:
        case GS_TYPE_BYTE_ARRAY:
        case GS_TYPE_SHORT_ARRAY:
        case GS_TYPE_INTEGER_ARRAY:
        case GS_TYPE_LONG_ARRAY:
        case GS_TYPE_FLOAT_ARRAY:
        case GS_TYPE_DOUBLE_ARRAY:
        case GS_TYPE_TIMESTAMP_ARRAY:
        default:
            //Not support for now
            return false;
            break;
    }
    return true;
}
}
%fragment("convertToFieldWithType", "header", fragment = "SWIG_AsCharPtrAndSize",
        fragment = "convertObjectToDouble", fragment = "convertObjectToGSTimestamp",
        fragment = "convertObjectToBlob", fragment = "convertObjectToBool",
        fragment = "convertObjectToFloat", fragment = "convertToGSValue") {
static bool convertToFieldWithType(GSRow *row, int column, VALUE value, GSType type) {

    bool vbool;
    GSResult ret;
    GSValue fieldValue = {0};

    if (rb_type(value) == T_NIL) {
%#if GS_COMPATIBILITY_SUPPORT_3_5
        ret = gsSetRowFieldGeneral(row, column, (const GSValue *) &fieldValue, GS_TYPE_NULL);
        return (ret == GS_RESULT_OK);
%#else
        //Not support NULL
        return false;
%#endif
    }

    vbool = convertToGSValue(value, type, &fieldValue);
    if (!vbool) {
        return false;
    }
    ret = gsSetRowFieldGeneral(row, column, (const GSValue *) &fieldValue, type);
    return (ret == GS_RESULT_OK);
}
}

/*
* fragment to support converting Field to VALUE support RowKeyPredicate, AggregationResult
*/
%fragment("convertFieldToObject", "header", fragment = "convertTimestampToObject") {
static VALUE convertFieldToObject(GSValue* value, GSType type, bool timestampToFloat = true) {

    switch (type) {
        case GS_TYPE_LONG:
            return INT2NUM(value->asLong);
        case GS_TYPE_STRING:
            return SWIG_FromCharPtrAndSize(value->asString, strlen(value->asString));
%#if GS_COMPATIBILITY_SUPPORT_3_5
        case GS_TYPE_NULL:
            NULL;
%#endif
        case GS_TYPE_INTEGER:
            return INT2NUM(value->asInteger);
        case GS_TYPE_DOUBLE:
            return SWIG_From_double(value->asDouble);
        case GS_TYPE_TIMESTAMP:
            return convertTimestampToObject(&value->asTimestamp, timestampToFloat);
        default:
            return NULL;
    }
    return NULL;
}
}

/**
 * Support convert row key Field from PyObject* to C Object with specific type
 */
%fragment("convertToRowKeyFieldWithType", "header", fragment = "SWIG_AsCharPtrAndSize",
          fragment = "convertObjectToDouble", fragment = "convertObjectToGSTimestamp") {
static bool convertToRowKeyFieldWithType(griddb::Field &field, VALUE value, GSType type) {
    field.type = type;

    if (rb_type(value) == T_NIL) {
        //Not support NULL
        return false;
    }

    int checkConvert = 0;
    switch (type) {
        case (GS_TYPE_STRING): {
            if (rb_type(value) != T_STRING) {
                return false;
            }
            char *mStr = StringValuePtr(value);
            field.value.asString = strdup(mStr);
            if (!field.value.asString) {
                // memory allocation false
                return false;
            }
            break;
        }
        case (GS_TYPE_INTEGER): {
            if (rb_type(value) != T_FIXNUM) {
                return false;
            }
            int64_t longVal = NUM2LONG(value);
            if (longVal < std::numeric_limits<int32_t>::min() ||
                longVal > std::numeric_limits<int32_t>::max()) {
                return false;
            }
            field.value.asInteger = (int32_t)longVal;
            break;
        }
        case (GS_TYPE_LONG): {
            if (rb_type(value) != T_FIXNUM && rb_type(value) != T_BIGNUM) {
                return false;
            }
            int64_t longVal = NUM2LONG(value);
            field.value.asInteger = (int32_t)longVal;
            break;
        }
        case (GS_TYPE_TIMESTAMP):
            return convertObjectToGSTimestamp(value, &field.value.asTimestamp);
            break;
        default:
            //Not support for now
            return false;
            break;
    }
    return true;
}
}

/**
 * Support convert data from GSRow* row to VALUE list 
 */
%fragment("getRowFields", "header", fragment = "convertTimestampToObject") {
static bool getRowFields(GSRow* row, int columnCount, GSType* typeList, bool timestampOutput, int* columnError, 
        GSType* fieldTypeError, VALUE outList) {
    GSResult ret;
    GSValue mValue;
    bool retVal = true;
    for (int i = 0; i < columnCount; i++) {
        //Check NULL value
        GSBool nullValue;
%#if GS_COMPATIBILITY_SUPPORT_3_5
        ret = gsGetRowFieldNull(row, (int32_t) i, &nullValue);
        if (ret != GS_RESULT_OK) {
            *columnError = i;
            retVal = false;
            *fieldTypeError = GS_TYPE_NULL;
            return retVal;
        }
        if (nullValue) {
            rb_ary_push(outList, NULL);
            continue;
        }
%#endif
        switch(typeList[i]) {
            case GS_TYPE_STRING: {
                GSChar* stringValue;
                ret = gsGetRowFieldAsString(row, (int32_t) i, (const GSChar **)&stringValue);
                VALUE strObj = SWIG_FromCharPtrAndSize(stringValue, strlen(stringValue));
                rb_ary_push(outList, strObj);
                break;
            }
            case GS_TYPE_BOOL: {
                GSBool boolValue;
                ret = gsGetRowFieldAsBool(row, (int32_t) i, &boolValue);
                rb_ary_push(outList, SWIG_From_bool(boolValue));
                break;
            }
            case GS_TYPE_BYTE: {
                int8_t byteValue;
                ret = gsGetRowFieldAsByte(row, (int32_t) i, &byteValue);
                rb_ary_push(outList, INT2NUM(byteValue));
                break;
            }
            case GS_TYPE_SHORT: {
                int16_t shortValue;
                ret = gsGetRowFieldAsShort(row, (int32_t) i, &shortValue);
                rb_ary_push(outList, INT2NUM(shortValue));
                break;
            }
            case GS_TYPE_INTEGER: {
                int32_t intValue;
                ret = gsGetRowFieldAsInteger(row, (int32_t) i, &intValue);
                rb_ary_push(outList, INT2NUM(intValue));
                break;
            }
            case GS_TYPE_LONG: {
                int64_t longValue;
                ret = gsGetRowFieldAsLong(row, (int32_t) i, &longValue);
                rb_ary_push(outList, LONG2NUM(longValue));
                break;
            }
            case GS_TYPE_FLOAT: {
                float floatValue;
                ret = gsGetRowFieldAsFloat(row, (int32_t) i, &floatValue);
                rb_ary_push(outList, SWIG_From_double(floatValue));
                break;
            }
            case GS_TYPE_DOUBLE: {
                double doubleValue;
                ret = gsGetRowFieldAsDouble(row, (int32_t) i, &doubleValue);
                rb_ary_push(outList, SWIG_From_double(doubleValue));
                break;
            }
            case GS_TYPE_TIMESTAMP: {
                GSTimestamp timestampValue;
                ret = gsGetRowFieldAsTimestamp(row, (int32_t) i, &timestampValue);
                rb_ary_push(outList, convertTimestampToObject(&timestampValue, timestampOutput));
                break;
            }
            case GS_TYPE_GEOMETRY: {
                GSChar* geoValue;
                ret = gsGetRowFieldAsGeometry(row, (int32_t) i, (const GSChar **)&geoValue);
                VALUE strObj = SWIG_FromCharPtrAndSize(geoValue, strlen(geoValue));
                rb_ary_push(outList, strObj);
                break;
            }
            case GS_TYPE_BLOB: {
                GSBlob blobValue = {0};
                ret = gsGetRowFieldAsBlob(row, (int32_t) i, &blobValue);
                VALUE strObj = SWIG_FromCharPtrAndSize((const char*)blobValue.data, blobValue.size);
                rb_ary_push(outList, strObj);
                break;
            }
            case GS_TYPE_STRING_ARRAY:
            case GS_TYPE_BOOL_ARRAY:
            case GS_TYPE_BYTE_ARRAY:
            case GS_TYPE_SHORT_ARRAY:
            case GS_TYPE_INTEGER_ARRAY:
            case GS_TYPE_LONG_ARRAY:
            case GS_TYPE_FLOAT_ARRAY:
            case GS_TYPE_DOUBLE_ARRAY:
            case GS_TYPE_TIMESTAMP_ARRAY:
            default: {
                // NOT OK
                ret = -1;
                break;
            }
        }
        if (ret != GS_RESULT_OK) {
            *columnError = i;
            *fieldTypeError = typeList[i];
            retVal = false;
            return retVal;
        }
    }
    return retVal;
}
}

/**
* Typemaps for hash for get_store()
*/
%typemap(typecheck) (const char* host, int32_t port, const char* cluster_name,
const char* database, const char* username, const char* password,
const char* notification_member, const char* notification_provider) {
    try {
        Check_Type($input, T_HASH);
        $1 = 1;
    } catch (const std::exception& e) {
        $1 = 0;
    }
}
%typemap(in) (const char* host, int32_t port, const char* cluster_name,
const char* database, const char* username, const char* password,
const char* notification_member, const char* notification_provider)
(VALUE keys_arr, VALUE key, VALUE val, int numArg, int i, int res = 0) {
    if (rb_type($input) !=  T_HASH) {
        %argument_fail(res, "Error: expect hash type", $symname, $argnum);
    }
    numArg = NUM2INT(rb_funcall($input, rb_intern("size"), 0, NULL));
    if (numArg <= 0 || numArg > 8) {
        %argument_fail(res, "Error: hash size is incorrect", $symname, $argnum);
    }

    $1 = NULL;
    $2 = 0;
    $3 = NULL;
    $4 = NULL;
    $5 = NULL;
    $6 = NULL;
    $7 = NULL;
    $8 = NULL;

    keys_arr = rb_funcall($input, rb_intern("keys"), 0, NULL);
    GSChar *tmpKey;
    for (i = 0; i < numArg; i++) {
        key = rb_ary_entry(keys_arr, i);
        if (rb_type(key) !=  T_STRING) {
         %argument_fail(res, "Error: expect hash type", $symname, $argnum);
        }
        tmpKey = StringValuePtr(key);
        val = rb_hash_aref($input, key);
        if (strcmp(tmpKey, "port") == 0) {
            if (rb_type(val) == T_FIXNUM) {
                $2 = NUM2INT(val);
            } else {
                %argument_fail(res, "Error: port type is int", $symname, $argnum);
            }
        } else {
            if (rb_type(val) !=  T_STRING) {
                %argument_fail(res, "Error: input must be string type", $symname, $argnum);
            }
            if (strcmp(tmpKey, "host") == 0) {
                $1 = StringValuePtr(val);
            } else if (strcmp(tmpKey, "cluster_name") == 0) {
                $3 = StringValuePtr(val);
            } else if (strcmp(tmpKey, "database") == 0) {
                $4 = StringValuePtr(val);
            } else if (strcmp(tmpKey, "username") == 0) {
                $5 = StringValuePtr(val);
            } else if (strcmp(tmpKey, "password") == 0) {
                $6 = StringValuePtr(val);
            } else if (strcmp(tmpKey, "notification_member") == 0) {
                $7 = StringValuePtr(val);
            } else if (strcmp(tmpKey, "notification_provider") == 0) {
                $8 = StringValuePtr(val);
            } else {
                %argument_fail(res, "Error: invalid key name", $symname, $argnum);
            }
        }
     }
}

/**
* Typemaps for new ContainerInfo()
*/
%typemap(typecheck) (const GSColumnInfo* props, int propsCount) {
    try {
        Check_Type($input, T_ARRAY);
        $1 = 1;
    } catch (const std::exception& e) {
        $1 = 0;
    }
}
%typemap(in, numinputs = 1) (const GSColumnInfo* props, int propsCount)
(VALUE ary_element, VALUE options_element, VALUE name_element, VALUE value_element, int res = 0) {
  Check_Type($input, T_ARRAY);
  $2 = NUM2INT(rb_funcall($input, rb_intern("length"), 0, NULL));
  $1 = NULL;
  if ($2 > 0) {
    $1 = new (nothrow) GSColumnInfo[$2]();
    if ($1 == NULL) {
        %argument_fail(res, "Memory allocation error", $symname, $argnum);
    }
    for (int i = 0; i < $2; i++) {
      ary_element = rb_ary_entry($input, i);
      Check_Type(ary_element, T_ARRAY);
      int size = NUM2INT(rb_funcall(ary_element, rb_intern("length"), 0, NULL));
      if (size != 2) {
%#if GS_COMPATIBILITY_SUPPORT_3_5
          if (size == 3) {
              options_element = rb_ary_entry(ary_element, 2);
              if (rb_type(options_element) !=  T_FIXNUM) {
                  %argument_fail(res, "Error: the options type for input is incorrect", $symname, $argnum);
              }
              $1[i].options = NUM2INT(options_element);
          } else {
              %argument_fail(res, "Error: The number of array is incorrect", $symname, $argnum);
          }
%#else
          %argument_fail(res, "Error: The number of array is incorrect", $symname, $argnum);
%#endif
      } else {
          $1[i].options = 0;
      }
      name_element  = rb_ary_entry(ary_element, 0);
      if (rb_type(name_element) != T_STRING) {
          %argument_fail(res, "Error: The name type for input is incorrect", $symname, $argnum);
      }
      $1[i].name    = StringValuePtr(name_element);
      value_element = rb_ary_entry(ary_element, 1);
      if (rb_type(value_element) != T_FIXNUM) {
          %argument_fail(res, "Error: the value type for input is incorrect", $symname, $argnum);
      }
      $1[i].type = NUM2INT(value_element);
    }
  }
}
%typemap(freearg) (const GSColumnInfo* props, int propsCount) {
  if ($1) {
    delete [] $1;
  }
}

/**
* Typemaps for StoreFactory::set_properties() function
*/
%typemap(in) (const GSPropertyEntry* props, int propsCount) 
(VALUE keys_ary, VALUE key, VALUE val, int res = 0) {
  Check_Type($input, T_HASH);
  $2 = NUM2INT(rb_funcall($input, rb_intern("size"), 0, NULL));
  $1 = NULL;
  if ($2 > 0) {
    $1 = new (nothrow) GSPropertyEntry[$2]();
    if ($1 == NULL) {
        %argument_fail(res, "Memory allocation error", $symname, $argnum);
    }
    keys_ary = rb_funcall($input, rb_intern("keys"), 0, NULL);
    for (int i = 0; i < $2; i++) {
      key = rb_ary_entry(keys_ary, i);
      val = rb_hash_aref($input, key);
      if (rb_type(key) != T_STRING || rb_type(val) != T_STRING) {
          %argument_fail(res, "Error: Need hash type for input", $symname, $argnum);
      }
      $1[i].name = StringValuePtr(key);
      $1[i].value = StringValuePtr(val);
    }
  }
}
%typemap(freearg) (const GSPropertyEntry* props, int propsCount) {
  if ($1) {
    delete [] $1;
  }
}

/**
* Typemaps for fetch_all() function
*/
%typemap(in) (GSQuery* const* queryList, size_t queryCount)
(int i, int res = 0, void* argp, std::shared_ptr<griddb::Query> query, VALUE val) {
  Check_Type($input, T_ARRAY);
  $2 = NUM2INT(rb_funcall($input, rb_intern("length"), 0, NULL));
  $1 = NULL;
  if ($2 > 0) {
    $1 = new (nothrow) GSQuery*[$2]();
    if ($1 == NULL) {
        %argument_fail(res, "Memory allocation error", $symname, $argnum);
    }
    for (i = 0; i < $2; i++) {
        val = rb_ary_entry($input, i);
        swig_ruby_owntype newmem = {0, 0};
        res = SWIG_ConvertPtrAndOwn(val, &argp, $descriptor(std::shared_ptr<griddb::Query> *), %convertptr_flags, &newmem);
        if (!SWIG_IsOK(res)) {
            %argument_fail(res, "get swigptr error", $symname, $argnum);
        }
        if (argp) {
            query = *%reinterpret_cast(argp, std::shared_ptr<griddb::Query>*);
            $1[i] = query->gs_ptr();
        }
        if (newmem.own & SWIG_CAST_NEW_MEMORY) {
            delete %reinterpret_cast(argp, std::shared_ptr<griddb::Query>*);
        }
    }
  }
}

%typemap(freearg) (GSQuery* const* queryList, size_t queryCount) {
  if ($1) {
    delete [] $1;
  }
}

/**
* Typemaps output for partition controller function
*/
%typemap(in, numinputs=0) (const GSChar *const ** stringList, size_t *size) 
(GSChar **nameList1, size_t size1) {
  $1 = &nameList1;
  $2 = &size1;
}

%typemap(argout,numinputs=0) (const GSChar *const ** stringList, size_t *size)
(VALUE arr,  int i, size_t size) {
    GSChar** nameList1 = *$1;
    VALUE arr = rb_ary_new2(*$2);
    for (int i = 0; i < *$2; i++) {
        rb_ary_push(arr, SWIG_FromCharPtrAndSize(nameList1[i], strlen(nameList1[i])));
    }
    $result = arr;
 }

%typemap(out) GSColumnInfo {
    $result = rb_hash_new();
    rb_hash_aset($result, SWIG_FromCharPtrAndSize($1.name, strlen($1.name)), INT2NUM($1.type));
}

/*
* typemap for get function in AggregationResult class
*/
%typemap(in, numinputs = 0) (griddb::Field *agValue) (griddb::Field tmpAgValue){
    $1 = &tmpAgValue;
}
%typemap(argout, fragment = "convertFieldToObject") (griddb::Field *agValue) {
    $result = convertFieldToObject(&($1->value), $1->type, arg1->timestamp_output_with_float);
}

/**
* Typemaps for RowSet.update() function
*/
%typemap(in, fragment = "convertToFieldWithType") (GSRow* row) {
    Check_Type($input, T_ARRAY);
    $1 = NULL;
    int len = NUM2INT(rb_funcall($input, rb_intern("length"), 0, NULL));
    if (len != arg1->getColumnCount()) {
        %variable_fail(1,"Error: ", "column number is incorrect");
    }
    GSRow *tmpRow = arg1->getGSRowPtr();
    GSType* typeList = arg1->getGSTypeList();
    for (int i = 0; i < len; i++) {
        GSType type = typeList[i];
        VALUE ary_element = rb_ary_entry($input, i);
        if (!(convertToFieldWithType(tmpRow, i, ary_element, type))) {
            char gsType[60];
            sprintf(gsType, "Invalid value for column %d, type should be : %d", i, type);
            %argument_fail(1, gsType, $symname, $argnum);
        }
    }
}

/**
* Typemaps for put_row() function
*/
%typemap(in, fragment = "convertToFieldWithType") (GSRow *rowContainer) {
    Check_Type($input, T_ARRAY);
    $1 = NULL;
    int len = NUM2INT(rb_funcall($input, rb_intern("length"), 0, NULL));
    if (len != arg1->getColumnCount()) {
        %variable_fail(1,"Error: ", "column number is incorrect");
    }
    GSRow* row = arg1->getGSRowPtr();
    GSType* typeList = arg1->getGSTypeList();
    for (int i = 0; i < len; i++) {
        GSType type = typeList[i];
        VALUE ary_element = rb_ary_entry($input, i);
        if (!(convertToFieldWithType(row, i, ary_element, type))) {
            char gsType[60];
            sprintf(gsType, "Invalid value for column %d, type should be : %d", i, type);
            %argument_fail(1, gsType, $symname, $argnum);
        }
    }
}

/*
* typemap for get_row
*/
%typemap(in, fragment = "convertToRowKeyFieldWithType") (griddb::Field* keyFields)
(griddb::Field field) {
    $1 = &field;
    if (rb_type($input) == T_NIL) {
%#if GS_COMPATIBILITY_SUPPORT_3_5
        $1->type = GS_TYPE_NULL;
%#else
        %variable_fail(1, "", "Not support for NULL");
%#endif
    } else {
        GSType* typeList = arg1->getGSTypeList();
        GSType type = typeList[0];
        if (!convertToRowKeyFieldWithType(*$1, $input, type)) {
            %variable_fail(1, "", "can not convert to row field");
        }
    }
}
%typemap(in, numinputs = 0) (GSRow *rowdata) {
    $1 = NULL;
}
%typemap(argout, fragment = "getRowFields") (GSRow *rowdata) {
    VALUE outList;
    if (result == GS_FALSE) {
        return NULL;
    } else {
        GSRow* row = arg1->getGSRowPtr();
        outList = rb_ary_new();
        bool retVal;
        int errorColumn;
        GSType errorType;
        retVal = getRowFields(row, arg1->getColumnCount(), arg1->getGSTypeList(), arg1->timestamp_output_with_float, &errorColumn, &errorType, outList);
        if (retVal == false) {
            char errorMsg[60];
            sprintf(errorMsg, "Can't get data for field %d with type%d", errorColumn, errorType);
            %variable_fail(1, "Error: ", errorMsg);
            SWIG_fail;
        }
        $result = outList;
    }
}

/**
 * Type map for Rowset::next()
 */
%typemap(in, numinputs = 0) (GSRowSetType* type, bool* hasNextRow,
griddb::QueryAnalysisEntry** queryAnalysis, griddb::AggregationResult** aggResult)
(GSRowSetType typeTmp, bool hasNextRowTmp,
griddb::QueryAnalysisEntry* queryAnalysisTmp = NULL,
griddb::AggregationResult* aggResultTmp = NULL) {
    $1 = &typeTmp;
    hasNextRowTmp = true;
    $2 = &hasNextRowTmp;
    $3 = &queryAnalysisTmp;
    $4 = &aggResultTmp;
}

%typemap(argout, fragment = "getRowFields") (GSRowSetType* type, bool* hasNextRow,
    griddb::QueryAnalysisEntry** queryAnalysis, griddb::AggregationResult** aggResult) {

    switch (*$1) {
        case (GS_ROW_SET_CONTAINER_ROWS): {
            bool retVal;
            int errorColumn;
            if (*$2 == false) {
                $result= NULL;
            } else {
                GSRow* row = arg1->getGSRowPtr();
                VALUE outList = rb_ary_new();
                if (rb_type(outList) == T_NIL) {
                    %variable_fail(1, "Error:", "Memory allocation for row is error");
                }
                GSType errorType;
                retVal = getRowFields(row, arg1->getColumnCount(), arg1->getGSTypeList(), arg1->timestamp_output_with_float, &errorColumn, &errorType, outList);
                if (retVal == false) {
                    char errorMsg[60];
                    sprintf(errorMsg, "Can't get data for field %d with type%d", errorColumn, errorType);
                    %variable_fail(1, "Error: ", errorMsg);
                    SWIG_fail;
                }
                $result = outList;
            }
            break;
        }
        case (GS_ROW_SET_AGGREGATION_RESULT): {
            std::shared_ptr< griddb::AggregationResult > *aggResult = NULL;
            if (*$2 == false) {
                $result= NULL;
            } else {
                aggResult = *$4 ? new (nothrow) shared_ptr< griddb::AggregationResult >(*$4 SWIG_NO_NULL_DELETER_SWIG_POINTER_OWN) : 0;
                $result = SWIG_NewPointerObj(SWIG_as_voidptr(aggResult), SWIGTYPE_p_std__shared_ptrT_griddb__AggregationResult_t, SWIG_POINTER_OWN | SWIG_POINTER_OWN);
                if (aggResult == NULL) {
                    %variable_fail(1, "Error:", "Memory allocation error");
                }
            }
            break;
        }
        case (GS_ROW_SET_QUERY_ANALYSIS): {
            std::shared_ptr< griddb::QueryAnalysisEntry >* queryAnalyResult = NULL;
            if (*$2 == false) {
                $result= NULL;
            } else {
                queryAnalyResult = *$3 ? new (nothrow) shared_ptr< griddb::QueryAnalysisEntry >(*$3 SWIG_NO_NULL_DELETER_SWIG_POINTER_OWN) : 0;
                $result = SWIG_NewPointerObj(SWIG_as_voidptr(queryAnalyResult), SWIGTYPE_p_std__shared_ptrT_griddb__QueryAnalysisEntry_t, SWIG_POINTER_OWN | SWIG_POINTER_OWN);
                if (queryAnalyResult == NULL) {
                    %variable_fail(1, "Error:", "Memory allocation error");
                }
            }
            break;
        }
        default: {
            %variable_fail(1, "Error:", "Invalid type");
            break;
        }
    }
    return $result;
}

/**
* Typemaps for create_index()/ drop_index function : support keyword parameter
*/
%typemap(typecheck) (const char* column_name, GSIndexTypeFlags index_type, const char* name) {
    try {
        Check_Type($input, T_HASH);
        $1 = 1;
    } catch (const std::exception& e) {
        $1 = 0;
    }
}
%typemap(in) (const char* column_name, GSIndexTypeFlags index_type, const char* name)
(VALUE keys_arr, VALUE key, VALUE val, int numArg, int i, int res = 0) {

    if (rb_type($input) !=  T_HASH) {
        %argument_fail(res, "Error: expect hash type", $symname, $argnum);
    }

    numArg = NUM2INT(rb_funcall($input, rb_intern("size"), 0, NULL));
    if (numArg < 1 || numArg > 3) {
        %argument_fail(res, "Error: hash size is incorrect", $symname, $argnum);
    }

    $1 = NULL;
    $2 = GS_INDEX_FLAG_DEFAULT;
    $3 = NULL;

    keys_arr = rb_funcall($input, rb_intern("keys"), 0, NULL);
    GSChar *tmpKey;
    for (i = 0; i < numArg; i++) {
        key = rb_ary_entry(keys_arr, i);
        if (rb_type(key) !=  T_STRING) {
         %argument_fail(res, "Error: expect hash type string", $symname, $argnum);
        }
        tmpKey = StringValuePtr(key);
        val = rb_hash_aref($input, key);
        if (strcmp(tmpKey, "column_name") == 0) {
            if (rb_type(val) !=  T_STRING) {
                %argument_fail(res, "Error: input must be string type", $symname, $argnum);
            }
            $1 = StringValuePtr(val);
        } else if (strcmp(tmpKey, "index_type") == 0) {
            if (rb_type(val) !=  T_FIXNUM) {
                %argument_fail(res, "Error: input must be int type", $symname, $argnum);
            }
            $2 = int(NUM2LONG(val));
        } else if (strcmp(tmpKey, "name") == 0) {
            if (rb_type(val) !=  T_STRING) {
                %argument_fail(res, "Error: input must be string type", $symname, $argnum);
            }
            $3 = StringValuePtr(val);
        } else {
            %argument_fail(res, "Error: invalid key name", $symname, $argnum);
        }
    }
}

/**
* Typemaps for set_fetch_options() : support keyword parameter
*/
%typemap(typecheck) (int limit, bool partial) {
    try {
        Check_Type($input, T_HASH);
        $1 = 1;
    } catch (const std::exception& e) {
        $1 = 0;
    }
}
%typemap(in) (int limit, bool partial)
(VALUE keys_arr, VALUE key, VALUE val, int numArg, int i, int res = 0) {

    if (rb_type($input) !=  T_HASH) {
        %argument_fail(res, "Error: expect hash type", $symname, $argnum);
    }

    numArg = NUM2INT(rb_funcall($input, rb_intern("size"), 0, NULL));
    if (numArg < 1 || numArg > 2) {
        %argument_fail(res, "Error: hash size is incorrect", $symname, $argnum);
    }

    $1 = INTEGER_MAX;
    $2 = false;

    keys_arr = rb_funcall($input, rb_intern("keys"), 0, NULL);
    GSChar *tmpKey;
    for (i = 0; i < numArg; i++) {
        key = rb_ary_entry(keys_arr, i);
        if (rb_type(key) !=  T_STRING) {
         %argument_fail(res, "Error: expect hash type string", $symname, $argnum);
        }
        tmpKey = StringValuePtr(key);
        val = rb_hash_aref($input, key);
        if (strcmp(tmpKey, "limit") == 0) {
            if (rb_type(val) !=  T_FIXNUM) {
                %argument_fail(res, "Error: input must be int type", $symname, $argnum);
            }
            $1 = int(NUM2LONG(val));
        } else if (strcmp(tmpKey, "partial") == 0) {
            if (rb_type(val) ==  T_TRUE) {
                $2 = true;
            } else if (rb_type(val) ==  T_FALSE) {
                $2 = false;
            } else {
                %argument_fail(res, "Error: input must be bool type", $symname, $argnum);
            }
        } else {
            %argument_fail(res, "Error: invalid key name", $symname, $argnum);
        }
    }
}

/**
* Typemaps for ContainerInfo : support keyword parameter ({"name" : str, "column_info_array" : array, "type" : str, 'row_key':boolean})
*/
%typemap(typecheck) (const GSChar* name, const GSColumnInfo* props, int propsCount,
GSContainerType type, bool row_key, griddb::ExpirationInfo* expiration) {
    try {
        Check_Type($input, T_HASH);
        $1 = 1;
    } catch (const std::exception& e) {
        $1 = 0;
    }
}
%typemap(in, numinputs = 1) (const GSChar* name, const GSColumnInfo* props, int propsCount,
GSContainerType type, bool row_key, griddb::ExpirationInfo* expiration)
(VALUE keys_arr, VALUE key, VALUE val, int numArg, int i, int res = 0,
VALUE ary_element, VALUE options_element, VALUE name_element, VALUE value_element,
void* argp, std::shared_ptr<griddb::ExpirationInfo> expiration) {

    if (rb_type($input) !=  T_HASH) {
        %argument_fail(res, "Error: expect hash type", $symname, $argnum);
    }

    numArg = NUM2INT(rb_funcall($input, rb_intern("size"), 0, NULL));
    if (numArg < 2 || numArg > 6) {
        %argument_fail(res, "Error: hash size is incorrect", $symname, $argnum);
    }

    $1 = NULL;
    $2 = NULL;
    $3 = 0;
    $4 = GS_CONTAINER_COLLECTION;//default value of type is GS_CONTAINER_COLLECTION
    $5 = true;//default rowKey value is true
    $6 = NULL;//default expiration value is null

    keys_arr = rb_funcall($input, rb_intern("keys"), 0, NULL);
    GSChar *tmpKey;
    for (i = 0; i < numArg; i++) {
        key = rb_ary_entry(keys_arr, i);
        if (rb_type(key) !=  T_STRING) {
         %argument_fail(res, "Error: expect hash type string", $symname, $argnum);
        }
        tmpKey = StringValuePtr(key);
        val = rb_hash_aref($input, key);
        if (strcmp(tmpKey, "name") == 0) {
            if (rb_type(val) !=  T_STRING) {
                %argument_fail(res, "Error: name input must be string type", $symname, $argnum);
            }
            $1 = StringValuePtr(val);
        } else if (strcmp(tmpKey, "type") == 0) {
            if (rb_type(val) !=  T_FIXNUM) {
                %argument_fail(res, "Error: name input must be int type", $symname, $argnum);
            }
            $4 = NUM2INT(val);
        } else if (strcmp(tmpKey, "row_key") == 0) {
            if (rb_type(val) ==  T_TRUE) {
                $5 = true;
            } else if (rb_type(val) ==  T_FALSE) {
                $5 = false;
            } else {
                %argument_fail(res, "Error: row_key input must be bool type", $symname, $argnum);
            }
        } else if (strcmp(tmpKey, "expiration") == 0) {
            if (rb_type(val) ==  T_NIL) {
                $6 = NULL;
            } else {
                swig_ruby_owntype newmem = {0, 0};
                res = SWIG_ConvertPtrAndOwn(val, &argp, $descriptor(std::shared_ptr<griddb::ExpirationInfo> *), %convertptr_flags, &newmem);
                if (!SWIG_IsOK(res)) {
                    %argument_fail(res, "get swigptr error", $symname, $argnum);
                }
                if (argp) {
                    expiration = *%reinterpret_cast(argp, std::shared_ptr<griddb::ExpirationInfo>*);
                    $6 = expiration.get();
                }
                if (newmem.own & SWIG_CAST_NEW_MEMORY) {
                    delete %reinterpret_cast(argp, std::shared_ptr<griddb::ExpirationInfo>*);
                }
            }
        } else if (strcmp(tmpKey, "column_info_array") == 0) {
            if (rb_type(val) !=  T_ARRAY) {
                %argument_fail(res, "column_info_array input must be array type", $symname, $argnum);
            }
            $3 = NUM2INT(rb_funcall(val, rb_intern("length"), 0, NULL));
            if ($3 > 0) {
                $2 = new (nothrow) GSColumnInfo[$3]();
                if ($2 == NULL) {
                    %argument_fail(res, "Memory allocation error", $symname, $argnum);
                }
                for (int j = 0; j < $3; j++) {
                  ary_element = rb_ary_entry(val, j);
                  if (rb_type(ary_element) !=  T_ARRAY) {
                      %argument_fail(res, "column_info_array's element input must be array type", $symname, $argnum);
                  }
                  int size = NUM2INT(rb_funcall(ary_element, rb_intern("length"), 0, NULL));
                  if (size != 2) {
%#if GS_COMPATIBILITY_SUPPORT_3_5
                      if (size == 3) {
                          options_element = rb_ary_entry(ary_element, 2);
                          if (rb_type(options_element) !=  T_FIXNUM) {
                              %argument_fail(res, "Error: the options type for input is incorrect", $symname, $argnum);
                          }
                          $2[j].options = NUM2INT(options_element);
                      } else {
                          %argument_fail(res, "Error: The number of array is incorrect", $symname, $argnum);
                      }
%#else
                      %argument_fail(res, "Error: The number of array is incorrect", $symname, $argnum);
%#endif
                  } else {
                      $2[j].options = 0;
                  }
                  name_element  = rb_ary_entry(ary_element, 0);
                  if (rb_type(name_element) != T_STRING) {
                      %argument_fail(res, "Error: The name type for input is incorrect", $symname, $argnum);
                  }
                  $2[j].name    = StringValuePtr(name_element);
                  value_element = rb_ary_entry(ary_element, 1);
                  if (rb_type(value_element) != T_FIXNUM) {
                      %argument_fail(res, "Error: the value type for input is incorrect", $symname, $argnum);
                  }
                  $2[j].type = NUM2INT(value_element);
                }
              }
        } else {
            %argument_fail(res, "Error: invalid key name", $symname, $argnum);
        }
    }
}
%typemap(freearg) (const GSChar* name, const GSColumnInfo* props, int propsCount,
GSContainerType type, bool row_key, griddb::ExpirationInfo* expiration) {
  if ($2) {
    delete [] $2;
  }
}

/**
 * Typemap for QueryAnalysisEntry.get()
 */
%typemap(in, numinputs = 0) (GSQueryAnalysisEntry* queryAnalysis) (GSQueryAnalysisEntry queryAnalysis1) {
    queryAnalysis1 = GS_QUERY_ANALYSIS_ENTRY_INITIALIZER;
    $1 = &queryAnalysis1;
}

%typemap(argout, fragment = "convertStrToObj") (GSQueryAnalysisEntry* queryAnalysis) () {
    VALUE outList = rb_ary_new();
    rb_ary_push(outList, INT2NUM($1->id));
    rb_ary_push(outList, INT2NUM($1->depth));
    rb_ary_push(outList, SWIG_FromCharPtrAndSize($1->type, strlen($1->type)));
    rb_ary_push(outList, SWIG_FromCharPtrAndSize($1->type, strlen($1->valueType)));
    rb_ary_push(outList, SWIG_FromCharPtrAndSize($1->type, strlen($1->value)));
    rb_ary_push(outList, SWIG_FromCharPtrAndSize($1->type, strlen($1->statement)));
    $result = outList;
}

%typemap(freearg) (GSQueryAnalysisEntry* queryAnalysis) {
    if ($1) {
        if ($1->statement) {
            free((void*) $1->statement);
        }
        if ($1->type) {
            free((void*) $1->type);
        }
        if ($1->value) {
            free((void*) $1->value);
        }
        if ($1->valueType) {
            free((void*) $1->valueType);
        }
    }
}

//attribute ContainerInfo.column_info_list
%typemap(typecheck) (ColumnInfoList*) {
    try {
        Check_Type($input, T_ARRAY);
        $1 = 1;
    } catch (const std::exception& e) {
        $1 = 0;
    }
}
%typemap(in) (ColumnInfoList*)
(int res = 0, VALUE val_info, int size_column, VALUE val, ColumnInfoList info_list) {
    Check_Type($input, T_ARRAY);
    $1 = &info_list;
    $1->size = NUM2INT(rb_funcall($input, rb_intern("length"), 0, NULL));
    $1->columnInfo = NULL;
    if ($1->size) {
        $1->columnInfo = new (nothrow) GSColumnInfo[$1->size]();
        if ($1->columnInfo == NULL) {
            %argument_fail(res, "Memory allocation error", $symname, $argnum);
        }
        for (int i = 0; i < $1->size; i++) {
            $1->columnInfo[i].indexTypeFlags = GS_INDEX_FLAG_DEFAULT;
            val_info = rb_ary_entry($input, i);
            if (rb_type(val_info) !=  T_ARRAY) {
                %argument_fail(res, "column info need array for input", $symname, $argnum);
            }
            size_column = NUM2INT(rb_funcall(val_info, rb_intern("length"), 0, NULL));
            if (size_column < 2) {
                %argument_fail(res, "Expect column info has 3 elements", $symname, $argnum);
            }
            val = rb_ary_entry(val_info, 0);
            if (rb_type(val) != T_STRING) {
                %argument_fail(res, "column name must be a string", $symname, $argnum);
            }
            $1->columnInfo[i].name = StringValuePtr(val);
            val = rb_ary_entry(val_info, 1);
            if (rb_type(val) != T_FIXNUM) {
                %argument_fail(res, "column type is incorrect", $symname, $argnum);
            }
            $1->columnInfo[i].type = NUM2INT(val);
            if (size_column == 2) {
                $1->columnInfo[i].options = 0;
            } else if (size_column == 3) {
                val = rb_ary_entry(val_info, 2);
                if (rb_type(val) != T_FIXNUM) {
                    %argument_fail(res, "column options is incorrect", $symname, $argnum);
                }
                $1->columnInfo[i].options = NUM2INT(val);
            } else {
                %argument_fail(res, "array length for column info is incorrect", $symname, $argnum);
            }
        }
    }
}
%typemap(freearg) (ColumnInfoList*) {
    if ($1->columnInfo != NULL) {
        delete [] $1->columnInfo;
    }
}
%typemap(out) (ColumnInfoList*) {
    VALUE out_list = rb_ary_new();
    for (int i = 0; i < $1->size; i++) {
        VALUE out_element = rb_ary_new();
        rb_ary_push(out_element, SWIG_FromCharPtrAndSize(($1->columnInfo)[i].name, strlen(($1->columnInfo)[i].name)));
        rb_ary_push(out_element, INT2NUM(($1->columnInfo)[i].type));
        rb_ary_push(out_element, INT2NUM(($1->columnInfo)[i].options));
        rb_ary_push(out_list, out_element);
    }
    $result = out_list;
}