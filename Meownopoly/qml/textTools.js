function caviarToken(token) {
    console.log("[JAVASCRIPT] Token : " + token)
    var caviarString = "";
    for(var i = 0; i < token.length - 8; i++)
        caviarString += "*";
    token = token.replace(token.substring(4, token.length - 4), caviarString);
    console.log("[JAVASCRIPT] Caviartoken : " + token)
    return token;
}
