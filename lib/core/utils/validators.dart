class TripMateValidators {
  
  static bool validarRutChileno(String rut) {
    rut = rut.replaceAll('.', '').replaceAll('-', '').trim().toUpperCase();
    
    if (rut.length < 8) return false;

    String cuerpo = rut.substring(0, rut.length - 1);
    String dv = rut.substring(rut.length - 1);

    int suma = 0;
    int multiplo = 2;

    for (int i = cuerpo.length - 1; i >= 0; i--) {
      try {
        suma += int.parse(cuerpo[i]) * multiplo;
      } catch (e) {
        return false; 
      }
      multiplo = (multiplo == 7) ? 2 : multiplo + 1;
    }

    int dvEsperadoInt = 11 - (suma % 11);
    String dvEsperado = (dvEsperadoInt == 11) 
        ? "0" 
        : (dvEsperadoInt == 10) 
            ? "K" 
            : dvEsperadoInt.toString();

    return dv == dvEsperado;
  }
  
}