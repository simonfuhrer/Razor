// Node.js Endpoint for ProjectRazor Image Service

var razor_bin = __dirname+ "/razor -w"; // Set project_razor.rb path
var exec = require("child_process").exec; // create our exec object
var express = require('express'); // include our express libs
var mime = require('mime');
var fs = require('fs');
var util = require('util');
var url = require("url");
var http_range_req = require('./http_range_req.js');
var image_svc_path;

app = express.createServer(); // our express server


app.get('/razor/image/mk*',
    function(req, res) {
        args = req.path.split("/");
        args.splice(0,3);
        var args_string = getArguments(args);
        if (args.length < 2) {
            args_string = args_string + "default "
        }
        console.log(razor_bin + " image path " + args_string);
        exec(razor_bin + " image path " + args_string, function (err, stdout, stderr) {
            console.log(stdout);
            path = getPath(stdout);
            respondWithFileMK(path, res)
        });
    });


app.get('/razor/image/*',
    function(req, res) {
        path = decodeURIComponent(req.path.replace(/^\/razor\/image/, image_svc_path));
        console.log(path);
        respondWithFile(path, res, req);
    });


function respondWithFileMK(path, res) {
    if (path != null) {
        var filename = path.split("/")[path.split("/").length - 1];

        res.setHeader('Content-disposition', 'attachment; filename=' + filename);
        res.writeHead(200, {'Content-Type': 'application/octet-stream'});

        var fileStream = fs.createReadStream(path);
        util.pump(fileStream, res);
    
    } else {
        res.send("Error", 404, {"Content-Type": "application/octet-stream"});
    }
}

function respondWithFile(path, res, req) {
    if (path != null) {
        try {
	    var range = typeof req.headers.range === "string" ? req.headers.range : undefined;
	    var reqUrl = url.parse(req.url, true);
	    var info = {};
            var mimetype = mime.lookup(path);
            var stat = fs.statSync(path);
	    var code = 200;
            var header;
            
	    info.start_offset = 0;
            info.end_offset = stat.size - 1;
            info.size = stat.size;
	    info.modified = stat.mtime;
	    info.rangeRequest = false;  

	    if (range !== undefined && (range = range.match(/bytes=(.+)-(.+)?/)) !== null) {
		// Check range contains numbers and they fit in the file.
	    	info.start_offset = isNumber(range[1]) && range[1] >= 0 && range[1] < info.end_offset ? range[1] - 0 : info.start_offset;
		info.end_offset = isNumber(range[2]) && range[2] > info.start_offset && range[2] <= info.end_offset ? range[2] - 0 : info.end_offset;
		info.rangeRequest = true;
	    } else if (reqUrl.query.start || reqUrl.query.end) {
		// This is a range request, but doesn't get range headers. So there
		info.start_offset = isNumber(reqUrl.query.start) && reqUrl.query.start >= 0 && reqUrl.query.start < info.end_offset ? reqUrl.query.start - 0 : info.start_offset;
		info.end_offset = isNumber(reqUrl.query.end) && reqUrl.query.end > info.start_offset && reqUrl.query.end <= info.end_offset ? reqUrl.query.end - 0 : info.end_offset;	
	    }

	    info.length = info.end_offset - info.start_offset + 1;
	    header = {
		"Cache-Control": "public",
		"Connection": "keep-alive",
		"Content-Type": mimetype,
		"Content-Disposition": "inline; filename=" + path + ";"
            };

	    if (info.rangeRequest) {
		// Partial http response
		code = 206;
		header.Status = "206 Partial Content";
		header["Accept-Ranges"] = "bytes";
		header["Content-Range"] = "bytes " + info.start_offset + "-" + info.end_offset + "/" + info.size;
	    }

	    header.Pragma = "public";
	    header["Last-Modified"] = info.modified.toUTCString();
	    header["Content-Length"] = info.length;
	    res.writeHead(code,header);
	    var filestream = fs.createReadStream(path, { flags: "r", start: info.start_offset, end: info.end_offset });
	    //util.pump(fileStream, res);
	    filestream.pipe(res);
            console.log("\tSending: " + path);
            console.log("\tMimetype: " + mimetype);
            console.log("\tSize: " + info.size);
            console.log("\tStart: " + info.start_offset + " / End: " + info.end_offset);
        }
        catch (err)
        {
            console.log("Error: " + err.message);
            res.send("Error: File Not Found", 404, {"Content-Type": "text/plain"});
        }

    } else {
        res.send("Error", 404, {"Content-Type": "text/plain"});
    }
}

function getPath(json_string) {
    var response = JSON.parse(json_string);
    if (response['errcode'] == 0) {
        return response['response'];
    } else {
        console.log("Error: finding file" )
        return null
    }

}

function getConfig() {
    exec(razor_bin + " config read", function (err, stdout, stderr) {
        //console.log(stdout);
        startServer(stdout);
    });
}

function getArguments(args_array) {
    var arg_string = " ";
    for (x = 0; x < args.length; x++) {
        arg_string = arg_string + args[x] + " "
    }
    return arg_string;
}

function isNumber(n) {
	return !isNaN(parseFloat(n)) && isFinite(n);
}

function getRange() {
    // This handles range requests per (http://tools.ietf.org/html/draft-ietf-http-range-retrieval-00)


}

// TODO Add catch for if project_razor.js is already running on port
// Start our server if we can get a valid config
function startServer(json_config) {
    var config = JSON.parse(json_config);
    if (config['@image_svc_port'] != null) {
        image_svc_path = config['@image_svc_path'];
        app.listen(config['@image_svc_port']);
        console.log("");
        console.log('ProjectRazor Image Service Web Server started and listening on:%s', config['@image_svc_port']);
        console.log("Image root path: " + image_svc_path);
    } else {
        console.log("There is a problem with your ProjectRazor configuration. Cannot load config.");
    }
}


mime.define({
    'text/plain': ['gpg']
});

getConfig();
