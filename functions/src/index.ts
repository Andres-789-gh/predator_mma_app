import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

// inicializa bd
admin.initializeApp();

// evalua vencimiento de planes
export const checkexpiringplans = onSchedule(
    {
        schedule: "0 9 * * *", // 9:00am
        timeZone: "America/Bogota",
    },
    async (event) => {
        const db = admin.firestore();
        const now = new Date();

        // calcula margen de 3 dias o menos
        const targetDate = new Date(now);
        targetDate.setDate(now.getDate() + 3);

        const startOfDay = new Date(now.setHours(0, 0, 0, 0)); // desde hoy
        const endOfDay = new Date(targetDate.setHours(23, 59, 59, 999)); // hasta en 3 dias

        try {
            const usersSnapshot = await db.collection("users").get();
            const batch = db.batch();
            let count = 0;

            usersSnapshot.forEach((userDoc) => {
                const userData = userDoc.data();
                const currentPlans = userData.currentPlans || [];

                for (const plan of currentPlans) {
                    if (plan.endDate) {
                        const endDate = plan.endDate.toDate();

                        // valida si vence hoy, mañana, o en 3 dias
                        if (endDate >= startOfDay && endDate <= endOfDay) {

                            // evita mandar spam si ya se le aviso
                            if (plan.notified_expiration === true) continue;

                            // noti cliente
                            const notifRefClient = db.collection("notifications").doc();
                            batch.set(notifRefClient, {
                                from_user_id: "system",
                                from_user_name: "Sistema",
                                to_role: "client",
                                to_user_id: userDoc.id,
                                title: "¡Atención con tu plan!",
                                body: `Tu plan ${plan.name} está por vencer o ya venció. Renuévalo pronto.`,
                                type: "NotificationType.planExpiring",
                                status: "NotificationStatus.pending",
                                payload: { plan_id: plan.id, plan_name: plan.name },
                                is_read: false,
                                created_at: admin.firestore.FieldValue.serverTimestamp(),
                                hidden_for: [],
                            });

                            // formato a fecha
                            const formatter = new Intl.DateTimeFormat('es-CO', {
                                day: '2-digit',
                                month: '2-digit',
                                year: 'numeric',
                                timeZone: 'America/Bogota'
                            });
                            const dateString = formatter.format(endDate);

                            // noti admins
                            const notifRefAdmin = db.collection("notifications").doc();
                            batch.set(notifRefAdmin, {
                                from_user_id: "system",
                                from_user_name: "sistema",
                                to_role: "admin",
                                to_user_id: null,
                                title: "vencimiento de plan",
                                body: `el plan ${plan.name} de ${userData.firstName} ${userData.lastName} vence el ${dateString}.`,
                                type: "NotificationType.planExpiring",
                                status: "NotificationStatus.pending",
                                payload: { user_id: userDoc.id, plan_id: plan.id },
                                is_read: false,
                                created_at: admin.firestore.FieldValue.serverTimestamp(),
                                hidden_for: [],
                            });

                            // marca el plan para no volver a avisar
                            plan.notified_expiration = true;

                            // actualiza el arreglo completo en bd
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
            console.log(`se generaron ${count} notificaciones de vencimiento.`);
        } catch (error) {
            console.error("falla en ejecucion:", error);
        }
    }
);

// envia reporte reservas a profes
export const sendcoachreports = onSchedule(
    {
        schedule: "0 0,12 * * *",
        timeZone: "America/Bogota",
    },
    async (event) => {
        const db = admin.firestore();
        const now = new Date();

        const windowStart = new Date(now);
        const windowEnd = new Date(now.getTime() + 12 * 60 * 60 * 1000);

        try {
            const classesSnapshot = await db
                .collection("classes")
                .where("startTime", ">=", windowStart)
                .where("startTime", "<=", windowEnd)
                .get();

            const batch = db.batch();
            let count = 0;

            classesSnapshot.forEach((doc) => {
                const classData = doc.data();

                // ignora clases canceladas
                if (classData.isCancelled === true) return;

                const coachId = classData.coachId;
                const classType = classData.classType || "clase";
                const attendeesCount = (classData.attendees || []).length;
                const startTimeDate = classData.startTime.toDate();

                // formato a hora
                const formatter = new Intl.DateTimeFormat('es-CO', {
                    hour: 'numeric',
                    minute: '2-digit',
                    hour12: true,
                    timeZone: 'America/Bogota'
                });
                const timeString = formatter.format(startTimeDate);
                const notifRef = db.collection("notifications").doc();

                // empaqueta alerta
                batch.set(notifRef, {
                    from_user_id: "system",
                    from_user_name: "sistema",
                    to_role: "coach",
                    to_user_id: coachId,
                    title: "reporte de clase",
                    body: `tu clase de ${classType} a las ${timeString} tiene ${attendeesCount} reservas.`,
                    type: "NotificationType.classReport",
                    status: "NotificationStatus.pending",
                    payload: { class_id: doc.id },
                    is_read: false,
                    created_at: admin.firestore.FieldValue.serverTimestamp(),
                    hidden_for: [],
                });

                count++;
            });

            if (count > 0) {
                await batch.commit();
            }
        } catch (error) {
            console.error("error en envio de reportes:", error);
        }
    }
);

// getillo, convierte notis locales en notis push
export const sendpushnotification = onDocumentCreated("notifications/{docId}", async (event) => {
    const snap = event.data;
    if (!snap) return;

    const notif = snap.data();
    const db = admin.firestore();

    const title = notif.title || "Notificación PREDATOR";
    const body = notif.body || "Tienes una nueva actualización.";
    const tokens: string[] = [];

    try {
        // caso a: noti pa un rol completo
        if (notif.to_role === "admin" && (!notif.to_user_id || notif.to_user_id === "")) {
            const adminsSnap = await db.collection("users").where("role", "==", "admin").get();
            adminsSnap.forEach((doc) => {
                const userData = doc.data();
                if (userData.notification_token) {
                    tokens.push(userData.notification_token);
                }
            });
        }
        // caso b: noti pa un usuario especifico
        else if (notif.to_user_id) {
            const userDoc = await db.collection("users").doc(notif.to_user_id).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                if (userData?.notification_token) {
                    tokens.push(userData.notification_token);
                }
            }
        }

        // aborta si no hay telefonos registrados
        if (tokens.length === 0) {
            console.log("No hay tokens válidos para enviar esta alerta.");
            return;
        }

        // empaqueta y dispara
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