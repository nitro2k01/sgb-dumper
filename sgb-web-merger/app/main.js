/*
	JS implementation of Super Game Boy Border Injector
	by Marc Robledo 2024
	
	see https://github.com/marcrobledo/super-game-boy-border-injector
*/

var romProgress=[
{
	name: "SGB beta version",
	fileName: "Super Game Boy (Japan, USA) (Beta).sfc",
	partialChecksums: [0x7364,0x47f3,0x93e1,0xa672,0x93b4,0xbeff,0x68af,0xe254,0x0d11,0x7e84,0x7d72,0x0000,0x8e16,0xf149,0x4198,0x8cd1,0x4a2b,0xc378,0xa69d,0x65e2,0x915f,0xafbe,0x03ee,0x90fa,0x1bd2,0x837a,0xdf80,0xadb2,0x42f7,0x5838,0x483b,0xd553]
},
{
	name: "SGB v 1.0",
	fileName: "Super Game Boy (J) (V1.0).smc",
	partialChecksums: [0x701d,0x4615,0x9387,0xa68d,0x93b4,0xbeff,0x685e,0xe302,0x0d11,0x7e84,0x7d72,0x0000,0x8e16,0xf149,0x4198,0x8cd1,0x4a2b,0xc378,0xa69d,0x65e2,0x915f,0xafbe,0x03ee,0x90fa,0x1bd2,0x837a,0xdf80,0xadb2,0x42f7,0x5838,0x483b,0xd59c]
},
{
	name: "SGB v 1.1",
	fileName: "Super Game Boy (JU) (V1.1) [!].smc",
	partialChecksums: [0x7364,0x47f3,0x93e1,0xa673,0x93b4,0xbeff,0x68af,0xe254,0x0d11,0x7e84,0x7d72,0x0000,0x8e16,0xf149,0x4198,0x8cd1,0x4a2b,0xc378,0xa69d,0x65e2,0x915f,0xafbe,0x03ee,0x90fa,0x1bd2,0x837a,0xdf80,0xadb2,0x42f7,0x5838,0x483b,0xd553]
},
{
	name: "SGB v 1.2",
	fileName: "Super Game Boy (UE) (V1.2) [!].smc",
	partialChecksums: [0x73f8,0x47f3,0x97f5,0xa674,0x93b4,0xbeff,0x68af,0xe254,0x0d11,0x7e84,0x7d72,0x0000,0x8e16,0xf149,0x4198,0x8cd1,0x4a2b,0xc378,0xa69d,0x65e2,0x915f,0xafbe,0x03ee,0x90fa,0x1bd2,0x837a,0xdf80,0xadb2,0x42f7,0x5838,0x483b,0x074a]
},
{
	name: "SGB2",
	fileName: "Super Game Boy 2 (Japan).sfc",
	partialChecksums: [0x7342,0x5123,0x98bb,0x9882,0x98fb,0xbeff,0x68af,0xe254,0x0d11,0x7e84,0x7d72,0x0000,0x8e16,0xf149,0x4198,0x8cd1,0x4a2b,0xc378,0xa69d,0x65e2,0x915f,0xafbe,0x03ee,0x90fa,0x1bd2,0x837a,0xdf80,0xadb2,0x42f7,0x5838,0x7436,0x074a,0xb292,0x4e09,0xcaa6,0xf4a7,0xa772,0x1558,0x667f,0x13a6,0x671e,0x5da3,0x875a,0x4904,0x37fb,0x2b6e,0xa72b,0xb2d2,0x3cf5,0x9c23,0x4c9e,0x395b,0x1cff,0x2051,0x723f,0x9145,0xe0e7,0xf9da,0x184a,0x5652,0x23b3,0x80a6,0x24b9,0x5f63]
}
]

function hex2(n){
	var retval = n.toString(16);
	return retval.length==1?'0'+retval:retval;
}

function hex4(n){
	var retval = n.toString(16);
	if (retval.length==1) return '000'+retval;
	if (retval.length==2) return '00'+retval;
	if (retval.length==3) return '0'+retval;
	return retval;
}


function generatePieceTitle(piece,checksum,found){
	return "Piece 0x" + hex2(piece) + " with checksum 0x" + hex4(checksum) + (found?" has been found.":" has not been found yet.");
}

function createROMStatusUI(){
	var containerElem = $('#roms-status');
	for(var i=0; i<romProgress.length; i++){
		var progressItem = romProgress[i];
		progressItem.havePieces = [];
		progressItem.progressElem=$('<div class="picker picker-neutral"></div>');
		// Add caption.
		$('<div id="picker-title-rom" class="picker-title"></div>').text(progressItem.name).appendTo(progressItem.progressElem);
		var pickerSubElem;

		for(var j=0; j<progressItem.partialChecksums.length; j++){
			if (j%16==0){
				pickerSubElem=$('<div class="picker-sub"></div>').appendTo(progressItem.progressElem);
			}
			var pieceInfo = {
				piece: null,
				hasPiece: false,
				hasPieceAcknowledged: false,
				elem: $('<span id="picker-status-border-map" class="picker-status"></span>').text(hex2(j)).appendTo(pickerSubElem)
			};
			pieceInfo.elem.attr("title", generatePieceTitle(j, progressItem.partialChecksums[j], false));

			progressItem.havePieces.push(pieceInfo);
		}
		$('<div class="picker-status-text">Have <span class="number-of-pieces">0</span> of <span>'+progressItem.partialChecksums.length+'</span> pieces of this ROM revision so far.</div>')
			.appendTo(progressItem.progressElem);

		let currentIndex = i, currentProgressItem = progressItem;
		$('<button type="button" class="btn btn-mainscope btn-ok"><img src="assets/octicon_download.svg" class="octicon" />Download</button>').on('click', function(evt) {
			//alert(romProgress[currentIndex].havePieces);
			//alert(currentIndex);
			var progressItem=romProgress[currentIndex];
			var fileBin = new Uint8Array(progressItem.havePieces.length*8192);
			console.log(fileBin.length)
			for(var k=0; k<progressItem.havePieces.length; k++){
				fileBin.set(progressItem.havePieces[k].piece,8192*k);
			}

			console.log(fileBin.length)

			var blob=new Blob([fileBin], {type: 'application/octet-stream'});
			saveAs(blob, progressItem.fileName);

			//alert(progressItem.fileName);

		}).appendTo(
			$('<div class="text-center mt-10 mb-10 button-container"></div>').appendTo(progressItem.progressElem)
		);

		progressItem.progressElem.appendTo(containerElem);

		//console.log(zzz.children());
	}
}



function setUpDragDropOverlay(){
	var enterCount=0;
	function delayedHide(){
		//console.log("Enter count: "+enterCount)
		if (enterCount==0){
			$('#modal-status-container').addClass('hidden')
		}
	}

	$('html').on('dragenter', function(evt) {
		//console.log("enter");console.log(evt);
		evt.preventDefault();
		enterCount++;
		$('#modal-status-container').removeClass('hidden')
	});

	$('html').on('dragleave', function(evt) {
		//console.log("leave");console.log(evt);
		evt.preventDefault();
		enterCount--;
		if(!enterCount){
			setTimeout(delayedHide,100)
		}
	});

	$('html').on('drop', function(evt) {
		//console.log("drop");console.log(evt);
		evt.preventDefault();
		enterCount--;
		$('#modal-status-container').addClass('hidden')
	});

	// Allow the user to reset the modal by clicking it, if it's shown incorrectly somehow.
	$('#modal-status-container').on('click', function(evt) {
		//console.log("reset");console.log(evt);
		enterCount=0;
		$('#modal-status-container').addClass('hidden')
	});
}

function moveFirst(elem){
	elem.parentNode.insertBefore(elem,elem.parentNode.childNodes[0]);
}

function calcChecksum(byteArray){
	var acc=0;
	for (var i=0; i<byteArray.length; i++){
		acc = (acc + byteArray[i]) & 0xFFFF;
	}
	return acc;
}

function submitSlices(slices){
	var sliceChecksums=[];
	for (var i = 0; i<slices.length; i++) {
		sliceChecksums.push(calcChecksum(slices[i]));
	}
	var numberOfPiecesHadTotalAllFiles=0;
	for(var i=0; i<romProgress.length; i++){
		var progressItem = romProgress[i];
		var numberOfPiecesAddedNow=0;
		var numberOfPiecesHadTotal=0;


		for(var j=0; j<progressItem.partialChecksums.length; j++){
			for (var k = 0; k < sliceChecksums.length; k++) {
				if (!progressItem.havePieces[j].hasPiece && progressItem.partialChecksums[j]==sliceChecksums[k]){
					progressItem.havePieces[j].hasPiece = true;
					progressItem.havePieces[j].piece = slices[k];
					progressItem.havePieces[j].elem.addClass("picker-ok");
					progressItem.havePieces[j].elem.attr("title", generatePieceTitle(j, progressItem.partialChecksums[j], true));
					numberOfPiecesAddedNow++;
				}
			}

			if(progressItem.havePieces[j].hasPiece){
				numberOfPiecesHadTotal++;
				numberOfPiecesHadTotalAllFiles++;
			}
		}

		progressItem.progressElem.find(".number-of-pieces").text(numberOfPiecesHadTotal);

		if(numberOfPiecesAddedNow>0){
			addStatus(numberOfPiecesAddedNow + " new pieces matched for ROM revision " + progressItem.name + ".");
		}

		if(numberOfPiecesHadTotal==progressItem.havePieces.length && numberOfPiecesAddedNow>0){
			addStatus(progressItem.name + " is ready to download!");
			progressItem.progressElem.addClass("file-ready");
			moveFirst(progressItem.progressElem[0]);
		}
	}
	if(numberOfPiecesHadTotalAllFiles==0){
		addStatus("No new pieces found in file.");
	}

}

function analyzeSingleFile(arrayBuffer,statusElem){
	var slices = [];
	for(var i=0;i<arrayBuffer.byteLength;i+=8192){
		var currentSlice = new Uint8Array(arrayBuffer.slice(i,i+8192));
		
		if(currentSlice.byteLength!=8192) break;
		slices.push(currentSlice);
	}
	submitSlices(slices);
}

function clearStatus(){
	$('#last-status').html('<p><b>Status:</b></p>');
}

function addStatus(msg){
	return $('<p></p>').text(msg).appendTo($('#last-status'))
}

function analyzeNextFile(files){
	if(files.length==0)
		return;

	var currentFile=files[0];
	files=files.slice(1);

	if(currentFile.size>4194304){
		addStatus("Skipping: " + currentFile.name + " (too big)");
		analyzeNextFile(files);
	}else{
		addStatus("Analyzing: " + currentFile.name);
		var fr=new FileReader();
		fr.onload=function(evt){
			analyzeSingleFile(this.result);
			analyzeNextFile(files);
		};
		fr.readAsArrayBuffer(currentFile);
	}

}

function analyzeFiles(files){
	// Don't erase status log if no files were detected. (Cancel, or dropped something that's not a file.)
	if(files.length==0) return;

	clearStatus();
	analyzeNextFile(Array.from(files));
}



$(document).ready((evt) => {	
	/* UI events */
	$('#btn-add-file').on('click', (evt) => {
		$('#input-file-rom').trigger('click');
	});

	$('#input-file-rom').on('change', function(evt) {
		if(this.files){
			analyzeFiles(this.files);
		}
	});

	createROMStatusUI();

	// The overlay is really just visual to tell the user that files can be dropped.
	setUpDragDropOverlay();

	$('html').on('drop', function(evt) {
		evt.preventDefault();
		analyzeFiles(evt.dataTransfer.files);
	});

	$('html').on('dragover', function(evt) {
		evt.preventDefault();
	});

	return;
});



function buildRepeatData(len, data){
	return Array(len).fill(data);
}
function findRepeatBytes(file, offset, len, repeatMany){
	file.seek(offset);
	var b=file.readByte();
	return findBytes(file, {offset:file.getOffset(), len:repeatMany || 1, data:buildRepeatData(len -1, b), reverse: false});
}

function findBytes(file, obj){
	var startOffset=obj.offset;
	var len=obj.len;
	var bytes=obj.data;
	var reverse=obj.reverse;

	for(var i=0; i<len; i++){
		var searchOffset;
		if(!reverse)
			searchOffset=startOffset+i;
		else
			searchOffset=startOffset-bytes.length-i;

		file.seek(searchOffset);
		var found=true;
		for(var j=0; j<bytes.length && found; j++){
			if(file.readByte()!==bytes[j]){
				found=false
			}
		}
		if(found)
			return searchOffset;
	}
	return null;
}
