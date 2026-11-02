import logging
import smtplib
from email.message import EmailMessage

from app.config import get_settings

log = logging.getLogger(__name__)


def send_mail(to: str, subject: str, body: str) -> bool:
    s = get_settings()
    if not s.smtp_host:
        if not s.is_production:
            log.warning("SMTP not configured; mail to %s not sent. Subject: %s\n%s", to, subject, body)
        return False
    msg = EmailMessage()
    msg["From"] = s.smtp_from
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(body)
    try:
        with smtplib.SMTP(s.smtp_host, s.smtp_port, timeout=15) as smtp:
            smtp.starttls()
            if s.smtp_user:
                smtp.login(s.smtp_user, s.smtp_password)
            smtp.send_message(msg)
        return True
    except (smtplib.SMTPException, OSError):
        log.exception("Failed to send mail")
        return False
