var dragging = false;
var draggingPiece = null;
var ghost = getDefaultGhost();

function mounted () {
    this.el.addEventListener("mousedown", event => {
        var piece = getPieceAtCursor(event.clientX, event.clientY);
        var square = getSquareAt(event.clientX, event.clientY);

        if (piece) {
            dragging = true;

            this.pushEventTo("#" + piece.id, "dragging-change", {dragging: dragging});
            this.pushEventTo("#chess-board", "mousedown", {col: piece.getAttribute("col"), row: piece.getAttribute("row")});

            ghost.src = piece.src;
            ghost.style.width = piece.width.toString() + "px";
            ghost.style.height = piece.height.toString() + "px";

            var coords = getCenterCoordinates(event.clientX, event.clientY, piece.width, piece.height);
            ghost.style.left = coords.x.toString() + "px"; ghost.style.top = coords.y.toString() + "px";
            ghost.style.display = "block";

            draggingPiece = piece;
        } else if (square) {
            this.pushEventTo("#chess-board", "mousedown", {col: square.getAttribute("col"), row: square.getAttribute("row")})
        }
    })

    document.addEventListener("mousemove", event => {
        if (dragging) {
            var coords = getCenterCoordinates(event.clientX, event.clientY, ghost.width, ghost.height);
            ghost.style.left = coords.x.toString() + "px"; ghost.style.top = coords.y.toString() + "px";
        }
    })

    document.addEventListener("mouseup", event => {
        var square = getSquareAt(event.clientX, event.clientY);

        var payload;
        if (square) {
            payload = {row: square.getAttribute("row"), col: square.getAttribute("col")}
        } else {
            payload = {row: "0", col: "0"};
        }

        this.pushEventTo("#chess-board", "mouseup", payload);

        if (dragging) {
            dragging = false;
            ghost.style.display = "none";

            this.pushEventTo("#" + draggingPiece.id, "dragging-change", {dragging: dragging})
        } 
        
        draggingPiece = null;
    })
}

function getCenterCoordinates(clientX, clientY, width, height) {
    var x = clientX - 0.5 * width;
    var y = clientY - 0.5 * height;
    return {x: x, y: y};
}

function getPieceAtCursor(x, y) {
    var elements = document.elementsFromPoint(x, y);
    var piece;
    for (let i = 0; i < elements.length; i++) {
        var e = elements[i];
        if (e.classList.contains("piece") && e.hasAttribute("row")) {
            piece = e;
        }
        // If a square has this class, the piece on that square is about to be captured, 
        //  so it cannot be dragged.
        if (e.classList.contains("select-circle-piece")) {
            return null;
        }
    }
    return piece;
}

function getSquareAt(x, y) {
    var elements = document.elementsFromPoint(x, y);
    for (let i = 0; i< elements.length; i++) {
        var e = elements[i];
        if (e.classList.contains("square") && e.hasAttribute("row")) {
            return e;
        }
    }
    return null;
}

function getDefaultGhost() {
    var ghost = document.createElement("img");

    ghost.setAttribute("draggable", "false");
    ghost.style.position = "absolute";
    ghost.style.display = "none";
    ghost.style.left = 0;
    ghost.style.top = 0;
    ghost.style.cursor = "grabbing";

    document.querySelector("body").appendChild(ghost);

    return ghost;
}

export default {mounted}