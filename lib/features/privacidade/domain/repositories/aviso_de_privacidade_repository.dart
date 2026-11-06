import '../entities/aviso_de_privacidade.dart';
import '../entities/ciencia_do_aviso.dart';

// O que a funcionalidade precisa dos dados, sem dizer de onde vêm (Supabase,
// cópia no celular). A implementação fica em data/.
abstract interface class AvisoDePrivacidadeRepository {
  // Aviso mais novo da [filial]; sem internet, a última cópia. null se nunca
  // baixou ou se a filial não tem aviso.
  Future<AvisoDePrivacidade?> buscar(String filial);

  // Última confirmação de leitura deste usuário nesta filial.
  Future<CienciaDoAviso?> ciencia(String email, String filial);

  Future<void> guardarCiencia(
      String email, String filial, CienciaDoAviso ciencia);
}
