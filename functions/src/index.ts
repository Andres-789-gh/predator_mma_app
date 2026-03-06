import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

// inicializa base de datos
admin.initializeApp();

// evalua vencimiento de planes
export const checkexpiringplans = onSchedule(
    {
        schedule: "0 9 * * *",
        timeZone: "America/Bogota",
    },
    async (event) => {
        const db = admin.firestore();
        const now = new Date();

        // calcula margen de tiempo
        const targetDate = new Date(now);
        targetDate.setDate(now.getDate() + 3);

        const startOfDay = new Date(now.setHours(0, 0, 0, 0));
        const endOfDay = new Date(targetDate.setHours(23, 59, 59, 999));

        try {
            const usersSnapshot = await db.collection("users").get();
            const batch = db.batch();
            let count = 0;

            usersSnapshot.forEach((userDoc) => {
                const userData = userDoc.data();

                // extrae planes del usuario
                const currentPlans = userData.current_plans || [];

                for (const plan of currentPlans) {
                    if (plan.end_date) {
                        const endDate = plan.end_date.toDate();

                        // valida ventana de vencimiento
                        if (endDate >= startOfDay && endDate <= endOfDay) {

                            // omite plan si ya fue notificado
                            if (plan.notified_expiration === true) continue;

                            // genera notificacion para cliente
                            const notifRefClient = db.collection("notifications").doc();
                            batch.set(notifRefClient, {
                                from_user_id: "system",
                                from_user_name: "Sistema",
                                to_role: "client",
                                to_user_id: userDoc.id,
                                title: "¡Vencimiento de plan!",
                                body: `Tu plan ${plan.name} está por vencer o ya venció. Renuévalo pronto.`,
                                type: "NotificationType.planExpiring",
                                status: "NotificationStatus.pending",
                                payload: { plan_id: plan.plan_id || plan.id, plan_name: plan.name },
                                is_read: false,
                                created_at: admin.firestore.FieldValue.serverTimestamp(),
                                hidden_for: [],
                            });

                            // formatea fecha de vencimiento
                            const formatter = new Intl.DateTimeFormat('es-CO', {
                                day: '2-digit',
                                month: '2-digit',
                                year: 'numeric',
                                timeZone: 'America/Bogota'
                            });
                            const dateString = formatter.format(endDate);

                            // extrae informacion personal
                            const firstName = userData.personal_info?.first_name || "Usuario";
                            const lastName = userData.personal_info?.last_name || "";

                            // genera notificacion para administrador
                            const notifRefAdmin = db.collection("notifications").doc();
                            batch.set(notifRefAdmin, {
                                from_user_id: "system",
                                from_user_name: "Sistema",
                                to_role: "admin",
                                to_user_id: null,
                                title: "Vencimiento de plan",
                                body: `El plan ${plan.name} de ${firstName} ${lastName} vence el ${dateString}.`,
                                type: "NotificationType.planExpiring",
                                status: "NotificationStatus.pending",
                                payload: { user_id: userDoc.id, plan_id: plan.plan_id || plan.id },
                                is_read: false,
                                created_at: admin.firestore.FieldValue.serverTimestamp(),
                                hidden_for: [],
                            });

                            // marca notificacion enviada
                            plan.notified_expiration = true;

                            // actualiza documento de usuario
                            batch.update(userDoc.ref, {
                                current_plans: currentPlans
                            });

                            count += 2;
                            break;
                        }
                    }
                }
            });

            if (count > 0) {
                await batch.commit();
            }
            console.log(`Se generaron ${count} notificaciones de vencimiento.`);
        } catch (error) {
            console.error("Falla en ejecución:", error);
        }
    }
);

// envia reporte a instructores
export const sendcoachreports = onSchedule(
    {
        schedule: "0 0,12 * * *",
        timeZone: "America/Bogota",
    },
    async (event) => {
        const db = admin.firestore();
        const now = new Date();

        // define ventana de tiempo
        const windowStart = new Date(now);
        const windowEnd = new Date(now.getTime() + 12 * 60 * 60 * 1000);

        try {
            // consulta clases en rango
            const classesSnapshot = await db
                .collection("classes")
                .where("start_time", ">=", windowStart)
                .where("start_time", "<=", windowEnd)
                .get();

            // agrupa clases por instructor
            const reportsByCoach: { [key: string]: string[] } = {};

            classesSnapshot.forEach((doc) => {
                const classData = doc.data();

                // omite clase cancelada
                if (classData.is_cancelled === true) return;

                // extrae datos
                const coachId = classData.coach_id;
                const classType = classData.type || "clase";
                const attendeesCount = (classData.attendees || []).length;
                const waitlistCount = (classData.waitlist || []).length;
                const startTimeDate = classData.start_time.toDate();

                // formatea hora
                const formatter = new Intl.DateTimeFormat('es-CO', {
                    hour: 'numeric',
                    minute: '2-digit',
                    hour12: true,
                    timeZone: 'America/Bogota'
                });
                const timeString = formatter.format(startTimeDate);

                // construye texto individual
                let classInfo = `• ${classType} (${timeString}): ${attendeesCount} reserva(s) confirmadas`;
                if (waitlistCount > 0) {
                    classInfo += `, ${waitlistCount} persona(s) en lista de espera`;
                }

                // inicializa arreglo de instructor
                if (!reportsByCoach[coachId]) {
                    reportsByCoach[coachId] = [];
                }
                reportsByCoach[coachId].push(classInfo);
            });

            const batch = db.batch();
            let count = 0;

            // genera alerta consolidada por instructor
            for (const [coachId, classesList] of Object.entries(reportsByCoach)) {
                const notifRef = db.collection("notifications").doc();
                const bodyText = classesList.join('\n');

                batch.set(notifRef, {
                    from_user_id: "system",
                    from_user_name: "Sistema",
                    to_role: "coach",
                    to_user_id: coachId,
                    title: "Asistencias clases",
                    body: `Tienes ${classesList.length} clase(s):\n\n${bodyText}`,
                    type: "NotificationType.classReport",
                    status: "NotificationStatus.pending",
                    payload: {},
                    is_read: false,
                    created_at: admin.firestore.FieldValue.serverTimestamp(),
                    hidden_for: [],
                });
                count++;
            }

            if (count > 0) {
                await batch.commit();
            }
        } catch (error) {
            console.error("Error en envío de reportes agrupados:", error);
        }
    }
);

// convierte notificacion local a push
export const sendpushnotification = onDocumentCreated("notifications/{docId}", async (event) => {
    const snap = event.data;
    if (!snap) return;

    const notif = snap.data();
    const db = admin.firestore();

    const title = notif.title || "Notificación PREDATOR";
    const body = notif.body || "Tienes una nueva actualización.";
    const tokens: string[] = [];

    try {
        // procesa envio a rol
        if (notif.to_role === "admin" && (!notif.to_user_id || notif.to_user_id === "")) {
            const adminsSnap = await db.collection("users").where("role", "==", "admin").get();
            adminsSnap.forEach((doc) => {
                const userData = doc.data();
                if (userData.notification_token) {
                    tokens.push(userData.notification_token);
                }
            });
        }
        // procesa envio a usuario
        else if (notif.to_user_id) {
            const userDoc = await db.collection("users").doc(notif.to_user_id).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                if (userData?.notification_token) {
                    tokens.push(userData.notification_token);
                }
            }
        }

        // detiene ejecucion sin tokens
        if (tokens.length === 0) {
            console.log("No hay tokens válidos para enviar esta alerta.");
            return;
        }

        // envia notificacion push
        const message = {
            notification: { title, body },
            tokens: tokens,
        };

        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Push enviada. Éxitos: ${response.successCount}, Fallos: ${response.failureCount}`);

    } catch (error) {
        console.error("Error crítico enviando Push:", error);
    }
});