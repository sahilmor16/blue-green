FROM python:3.9-slim

WORKDIR /app

COPY web/ .

RUN pip install flask

EXPOSE 5000

CMD ["python", "python.py"]
