var url = window.location.protocol + "//" + window.location.host + "/jay/rpc";

$(window).load(function() {
	$('#systemWorking').css('display', 'none');
	$('#Send').click(function() {
		var input = $("#Input").val();
		makeCall(input);
	});
});

function makeCall(data)
{
	if(data == undefined) return;
	
	$.ajax({
		url: url,
		type: 'POST',
		data : data,
		dataType: 'json',
		timeout: 1000,
		beforeSend : function(){
			$('#systemWorking').css('display', 'block');
		},
		error: function(){
			$('#systemWorking').css('display', 'none');
			alert('Error loading document');
		},
		success: function(json){
			$('#systemWorking').css('display', 'none');
			var output = $.toJSON(json);
			$("#Output").val(output);
		}
	});
};
