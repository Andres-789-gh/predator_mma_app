// Roles
enum UserRole {
  admin,    // Socios y Profesor Principal (Acceso Total)
  coach,    // Profesores Externos (Solo ven sus propias clases)
  client    // Alumnos / Clientes (Reservan y ven su perfil)
}

// Categoria de clases (Etiquetas)
enum ClassCategory {
  combat,           
  conditioning,
  kids,
  personalized,
  virtual
}

// Consumo del plan
enum PlanConsumptionType {
  limitedDaily, // 1 ingreso diario
  unlimited,    // ingresos ilimitados
  pack          // paquete de clases (personalizadas)
}

// Estado de una reserva
enum BookingStatus {
  confirmed,      // Tiene cupo asegurado
  waitlist,       // Está en cola de espera
  none            // Default (cancelo o nunca registro)
}

enum ClassStatus {
  reserved,       // agendada 
  available,      // Puede reservar
  availableWithTicket, // Ticket (ingreso extra)
  blockedByPlan,  // Plan no deja y no tiene tickets
  full,           // Clase llena
  waitlist
}

enum ClassEditMode {
  single,   // solo esta clase
  similar,  // todas las similares (mismo dia/hora/tipo)
  allType   // todas las de este tipo
}