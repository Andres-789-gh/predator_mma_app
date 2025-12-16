// Roles
enum UserRole {
  admin,    // Socios y Profesor Principal (Acceso Total)
  coach,    // Profesores Externos (Solo ven sus propias clases)
  client    // Alumnos / Clientes (Reservan y ven su perfil)
}

// Tipos de Planes
enum PlanType {
  wild,           // Mañanas, 1 diaria
  full,           // Todo horario, 1 diaria
  unlimited,      // Todo horario, Ilimitado
  fitness,        // Solo clases de Acondicionamiento
  weekends,       // Sábados y Domingos
  kids,           // Martes y Jueves (Niños)
  personalized,   // Paquete de clases (4, 8, 12, 16)
  virtual         // Clases virtuales
}

// Estado de una reserva
enum BookingStatus {
  confirmed,      // Tiene cupo asegurado
  waitlist,       // Está en cola de espera
  none            // Default (cancelo o nunca registro)
}