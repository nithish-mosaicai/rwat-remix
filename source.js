const apiResponse = await Functions.makeHttpRequest({
  url: 'https://geniebackbone.azurewebsites.net/api/properties/demo'
});

const { data } = apiResponse.data; // Accessing the 'data' object from the API response
console.log('API response data:', JSON.stringify(apiResponse, null, 2));

const location = data.location;
const lotSize = Number(data.lotSize); // Convert lotSize to Number
const totalPrice = Number(data.totalPrice); // Convert totalPrice to Number
const taxAssessedValue = Number(data.taxAssessedValue); // Convert taxAssessedValue to Number

const response = {
  location,
  lotSize,
  totalPrice,
  taxAssessedValue
};

const jsonResponse = JSON.stringify(response, null, 2);
return Buffer.from(jsonResponse);
