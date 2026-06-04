import { sendEmail } from "./services/email.service.js";
import config from "./config/index.js";

(async () => {
  console.log("frontend url:", config.FRONTEND_URL);
  const result = await sendEmail({
    to: "example@example.com",
    subject: "Test email",
    template: "password-reset",
    data: {
      name: "Tester",
      resetLink: "https://example.com/",
      expiresIn: "10 minutes",
    },
  });
  console.log(result);
})();
