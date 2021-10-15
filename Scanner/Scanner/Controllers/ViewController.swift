//
//  ViewController.swift
//  Scanner
//
//  Created by George on 15.10.21.
//

import UIKit
import VisionKit
import Vision

class ViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!

    @IBOutlet weak var warningLbl: UILabel!
    @IBOutlet weak var fileNameTF: UITextField!
    @IBOutlet weak var textView: UITextView!

    let fileManager = FileManager()
    let tempDir = NSTemporaryDirectory()

    lazy var workQueue = {
        return DispatchQueue(label: "workQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    }()

    lazy var textRecognitionRequest: VNRecognizeTextRequest = {
        let req = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            var resultText = ""
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { return }
                resultText += topCandidate.string
                resultText += "\n"
            }

            DispatchQueue.main.async {
                self.textView.text = resultText
            }
        }
        return req
    }()
    
    override func viewWillAppear(_ animated: Bool) {
       self.startKeyboardObserver()
    }

    func configureDocView() {
        let scanDocView = VNDocumentCameraViewController()
        scanDocView.delegate = self
        self.present(scanDocView, animated: true, completion: nil)
    }

    func recognizeText(inImage: UIImage) {
        guard let cgImage = inImage.cgImage else { return }

        workQueue.async {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try requestHandler.perform([self.textRecognitionRequest])
            } catch {
                print(error)
            }
        }
    }


    @IBAction func savePdf(_ sender: Any) {
        convertToPdfFileAndShare()
    }

    @IBAction func saveTxt(_ sender: Any) {
        guard let name = fileNameTF.text else {
            GlobalFunctions.shared.showError(withText: Warnings.nameError, label: self.warningLbl)
            return
        }
        guard let text = textView.text else {
            GlobalFunctions.shared.showError(withText: Warnings.textError, label: self.warningLbl)
            return
        }

        let path = (tempDir as NSString).appendingPathComponent(name)

        do {
            try text.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
            GlobalFunctions.shared.showError(withText: Warnings.success, label: self.warningLbl)
        } catch let error as NSError {
            GlobalFunctions.shared.showError(withText: Warnings.createError + "\(error)", label: self.warningLbl)
        }
    }

    @IBAction func readTxt(_ sender: Any) {

        let directoryWithFiles = checkDirectory() ?? "Empty"

        let path = (tempDir as NSString).appendingPathComponent(directoryWithFiles)

        do {
            let contentsOfFile = try NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
            textView.text = "content of the file is: \(contentsOfFile)"
        } catch let error as NSError {
            GlobalFunctions.shared.showError(withText: "\(error)", label: self.warningLbl)
        }
    }

    private func checkDirectory() -> String? {
        guard let name = fileNameTF.text else { return nil }

        do {
            let filesInDirectory = try fileManager.contentsOfDirectory(atPath: tempDir)

            if !filesInDirectory.isEmpty {
                let files = filesInDirectory.filter { fileNameDir -> Bool in
                    fileNameDir == name
                }
                if !files.isEmpty {
                    GlobalFunctions.shared.showError(withText: "\(name) found", label: self.warningLbl)
                    return files.first
                } else {
                    GlobalFunctions.shared.showError(withText: "\(name) not found", label: self.warningLbl)
                    return nil
                }
            }
        } catch let error as NSError {
            GlobalFunctions.shared.showError(withText: "\(error)", label: self.warningLbl)
        }
        return nil
    }

    func convertToPdfFileAndShare() {
        guard let name = fileNameTF.text else {
            GlobalFunctions.shared.showError(withText: Warnings.nameError, label: self.warningLbl)
            return
        }
        guard let text = textView.text else {
            GlobalFunctions.shared.showError(withText: Warnings.textError, label: self.warningLbl)
            return
        }

        let fmt = UIMarkupTextPrintFormatter(markupText: text)

        let render = UIPrintPageRenderer()
        render.addPrintFormatter(fmt, startingAtPageAt: 0)

        let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        render.setValue(page, forKey: "paperRect")
        render.setValue(page, forKey: "printableRect")

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)

        for i in 0..<render.numberOfPages {
            UIGraphicsBeginPDFPage()
            render.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }

        UIGraphicsEndPDFContext()

        guard let outputURL = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(name).appendingPathExtension("pdf")
            else { fatalError("Destination URL not created") }

        pdfData.write(to: outputURL, atomically: true)
        print("open \(outputURL.path)")

        if FileManager.default.fileExists(atPath: outputURL.path) {

            let url = URL(fileURLWithPath: outputURL.path)
            let activityViewController: UIActivityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self.view

            present(activityViewController, animated: true, completion: nil)

        }
        else {
            print("document was not found")
        }

    }

    @IBAction func scanDoc(_ sender: Any) {
        configureDocView()
    }

}

extension ViewController: VNDocumentCameraViewControllerDelegate {

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        for pageNum in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: pageNum)
            recognizeText(inImage: image)
        }
        controller.dismiss(animated: true, completion: nil)
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        print(error)
        controller.dismiss(animated: true)
    }
}

extension ViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }

    private func startKeyboardObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func keyboardWillShow(notification: Notification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardSize.height, right: 0.0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }

    @objc func keyboardWillHide() {
        let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }
}

